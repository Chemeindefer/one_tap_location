// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.batuhandelice.one_tap_location

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.IBinder
import android.view.SurfaceControlViewHost
import androidx.annotation.RequiresApi
import java.lang.reflect.Constructor
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method
import java.lang.reflect.Proxy
import java.util.concurrent.Executor

/** The first API level that ships the system location button (Android 17). */
internal const val SYSTEM_BUTTON_API_LEVEL = 37

private const val PERMISSION_UI_PACKAGE = "android.app.permissionui"

/**
 * The appearance of a system location button.
 *
 * Dimensions are in pixels. Null properties keep the system defaults.
 */
internal data class SystemButtonAppearance(
    val textType: Int,
    val backgroundColor: Int? = null,
    val foregroundColor: Int? = null,
    val strokeColor: Int? = null,
    val strokeWidth: Int? = null,
    val cornerRadius: Float? = null,
    val pressedCornerRadius: Float? = null,
)

/** A session in which the system renders one location button. */
internal interface SystemButtonSession {
    /** The surface to embed with `SurfaceView.setChildSurfacePackage`. */
    val surfacePackage: SurfaceControlViewHost.SurfacePackage

    fun resize(width: Int, height: Int)

    fun changeConfiguration(configuration: Configuration)

    /** Applies the properties of [appearance] that are not null. */
    fun applyAppearance(appearance: SystemButtonAppearance)

    fun close()
}

/** Receives the callbacks of a session on the executor the session was opened with. */
internal interface SystemButtonClient {
    fun onSessionOpened(session: SystemButtonSession)

    fun onPermissionResult(isGranted: Boolean)

    /** Called when the session failed. The session is already closed. */
    fun onSessionError(error: Throwable)
}

/**
 * Opens sessions of the system location button.
 *
 * The platform API is reached through reflection, so the plugin keeps compiling against SDK 36, the
 * default of Flutter apps.
 */
internal class SystemButtonProvider private constructor(
    private val api: PermissionUiApi,
    private val provider: Any,
) {
    @RequiresApi(SYSTEM_BUTTON_API_LEVEL)
    fun openSession(
        activity: Activity,
        hostToken: IBinder,
        displayId: Int,
        width: Int,
        height: Int,
        appearance: SystemButtonAppearance,
        executor: Executor,
        client: SystemButtonClient,
    ) {
        val request = api.buildRequest(width, height, activity.resources.configuration, appearance)
        api.openSession(provider, activity, hostToken, displayId, request, executor, client)
    }

    companion object {
        /** Whether the device renders the system location button. */
        fun isAvailable(context: Context): Boolean =
            Build.VERSION.SDK_INT >= SYSTEM_BUTTON_API_LEVEL &&
                PermissionUiApi.instance != null &&
                hasRenderService(context)

        /**
         * Whether the service that renders the button is installed and enabled. The platform binds
         * to that service when a session opens, so a build without it cannot show the button. The
         * service is looked up the way the platform looks it up, through the resources of [context].
         */
        @RequiresApi(SYSTEM_BUTTON_API_LEVEL)
        private fun hasRenderService(context: Context): Boolean {
            val resources = context.resources
            // The configuration is internal to the platform, so it is looked up by name.
            @SuppressLint("DiscouragedApi")
            val id = resources.getIdentifier(
                "config_locationButtonRenderService",
                "string",
                "android",
            )
            val service = if (id == 0) {
                null
            } else {
                ComponentName.unflattenFromString(resources.getString(id))
            }
            return service != null &&
                context.packageManager.resolveService(
                    Intent().setComponent(service),
                    PackageManager.ResolveInfoFlags.of(0),
                ) != null
        }

        /**
         * Creates a provider, or returns null when the system location button is unavailable. Must
         * be called on a thread with a looper.
         */
        fun create(context: Context): SystemButtonProvider? {
            val api = PermissionUiApi.instance ?: return null
            return SystemButtonProvider(api, api.createProvider(context))
        }
    }
}

private class PermissionUiApi(
    private val create: Method,
    private val openSession: Method,
    private val clientInterface: Class<*>,
    private val builderConstructor: Constructor<*>,
    private val builderAppearance: AppearanceSetters,
    private val build: Method,
    private val getSurfacePackage: Method,
    private val resize: Method,
    private val changeConfiguration: Method,
    private val sessionAppearance: AppearanceSetters,
    private val close: Method,
) {
    fun createProvider(context: Context): Any = invoke(create, null, context)!!

    fun buildRequest(
        width: Int,
        height: Int,
        configuration: Configuration,
        appearance: SystemButtonAppearance,
    ): Any {
        val builder = try {
            builderConstructor.newInstance(width, height, configuration)
        } catch (exception: InvocationTargetException) {
            throw exception.cause ?: exception
        }
        builderAppearance.apply(builder, appearance)
        return invoke(build, builder)!!
    }

    @RequiresApi(SYSTEM_BUTTON_API_LEVEL)
    fun openSession(
        provider: Any,
        activity: Activity,
        hostToken: IBinder,
        displayId: Int,
        request: Any,
        executor: Executor,
        client: SystemButtonClient,
    ) {
        val proxy = Proxy.newProxyInstance(
            clientInterface.classLoader,
            arrayOf(clientInterface),
        ) { proxy, method, arguments ->
            if (method.declaringClass == Any::class.java) {
                return@newProxyInstance when (method.name) {
                    "equals" -> proxy === arguments?.firstOrNull()
                    "hashCode" -> System.identityHashCode(proxy)
                    else ->
                        "SystemButtonClient@${Integer.toHexString(System.identityHashCode(proxy))}"
                }
            }
            when (method.name) {
                "onSessionOpened" -> client.onSessionOpened(ReflectedSession(arguments!![0]))
                "onPermissionResult" -> client.onPermissionResult(arguments!![0] as Boolean)
                // A tap that reuses the one-time intent of the previous tap cannot open the
                // confirmation, and the platform reports that without a cause while the session
                // stays open.
                "onSessionError" ->
                    (arguments!![0] as Throwable?)?.let(client::onSessionError)
            }
            null
        }
        invoke(openSession, provider, activity, hostToken, displayId, request, executor, proxy)
    }

    @RequiresApi(SYSTEM_BUTTON_API_LEVEL)
    private inner class ReflectedSession(private val session: Any) : SystemButtonSession {
        override val surfacePackage: SurfaceControlViewHost.SurfacePackage
            get() = invoke(getSurfacePackage, session) as SurfaceControlViewHost.SurfacePackage

        override fun resize(width: Int, height: Int) {
            invoke(resize, session, width, height)
        }

        override fun changeConfiguration(configuration: Configuration) {
            invoke(changeConfiguration, session, configuration)
        }

        override fun applyAppearance(appearance: SystemButtonAppearance) {
            sessionAppearance.apply(session, appearance)
        }

        override fun close() {
            invoke(close, session)
        }
    }

    companion object {
        val instance: PermissionUiApi? by lazy { load() }

        private fun load(): PermissionUiApi? {
            if (Build.VERSION.SDK_INT < SYSTEM_BUTTON_API_LEVEL) {
                return null
            }
            return try {
                resolve()
            } catch (exception: ReflectiveOperationException) {
                null
            } catch (error: LinkageError) {
                null
            }
        }

        private fun resolve(): PermissionUiApi {
            // Methods are looked up on the public interfaces: the implementation classes are
            // internal to the platform and cannot be invoked directly.
            val factory = type("LocationButtonProviderFactory")
            val provider = type("LocationButtonProvider")
            val client = type("LocationButtonClient")
            val session = type("LocationButtonSession")
            val request = type("LocationButtonRequest")
            val builder = type("LocationButtonRequest\$Builder")
            val int = Int::class.javaPrimitiveType!!
            return PermissionUiApi(
                create = factory.getMethod("create", Context::class.java),
                openSession = provider.getMethod(
                    "openSession",
                    Activity::class.java,
                    IBinder::class.java,
                    int,
                    request,
                    Executor::class.java,
                    client,
                ),
                clientInterface = client,
                builderConstructor = builder.getConstructor(int, int, Configuration::class.java),
                builderAppearance = AppearanceSetters.resolve(builder),
                build = builder.getMethod("build"),
                getSurfacePackage = session.getMethod("getSurfacePackage"),
                resize = session.getMethod("resize", int, int),
                changeConfiguration =
                    session.getMethod("changeConfiguration", Configuration::class.java),
                sessionAppearance = AppearanceSetters.resolve(session),
                close = session.getMethod("close"),
            )
        }

        private fun type(name: String): Class<*> = Class.forName("$PERMISSION_UI_PACKAGE.$name")
    }
}

/** The appearance setters that the request builder and the session have in common. */
private class AppearanceSetters(
    private val setTextType: Method,
    private val setBackgroundColor: Method,
    private val setTextColor: Method,
    private val setIconTint: Method,
    private val setStrokeColor: Method,
    private val setStrokeWidth: Method,
    private val setCornerRadius: Method,
    private val setPressedCornerRadius: Method,
) {
    fun apply(target: Any, appearance: SystemButtonAppearance) {
        invoke(setTextType, target, appearance.textType)
        appearance.backgroundColor?.let { invoke(setBackgroundColor, target, it) }
        appearance.foregroundColor?.let {
            invoke(setTextColor, target, it)
            invoke(setIconTint, target, it)
        }
        appearance.strokeColor?.let { invoke(setStrokeColor, target, it) }
        appearance.strokeWidth?.let { invoke(setStrokeWidth, target, it) }
        appearance.cornerRadius?.let { invoke(setCornerRadius, target, it) }
        appearance.pressedCornerRadius?.let { invoke(setPressedCornerRadius, target, it) }
    }

    companion object {
        fun resolve(type: Class<*>): AppearanceSetters {
            val int = Int::class.javaPrimitiveType!!
            val float = Float::class.javaPrimitiveType!!
            return AppearanceSetters(
                setTextType = type.getMethod("setTextType", int),
                setBackgroundColor = type.getMethod("setBackgroundColor", int),
                setTextColor = type.getMethod("setTextColor", int),
                setIconTint = type.getMethod("setIconTint", int),
                setStrokeColor = type.getMethod("setStrokeColor", int),
                setStrokeWidth = type.getMethod("setStrokeWidth", int),
                setCornerRadius = type.getMethod("setCornerRadius", float),
                setPressedCornerRadius = type.getMethod("setPressedCornerRadius", float),
            )
        }
    }
}

private fun invoke(method: Method, target: Any?, vararg arguments: Any?): Any? {
    return try {
        method.invoke(target, *arguments)
    } catch (exception: InvocationTargetException) {
        throw exception.cause ?: exception
    }
}
