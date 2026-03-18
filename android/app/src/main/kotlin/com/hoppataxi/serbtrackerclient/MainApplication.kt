package com.hoppataxi.serbtrackerclient

import android.app.Application
import org.slf4j.LoggerFactory

class MainApplication : Application() {
    override fun onCreate() {
        LoggerFactory.getILoggerFactory()
        super.onCreate()
    }
}
