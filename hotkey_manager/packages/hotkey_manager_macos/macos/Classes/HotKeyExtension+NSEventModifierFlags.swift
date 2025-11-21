//
//  HotKeyExtension+NSEventModifierFlags.swift
//  hotkey_manager
//
//  Created by Lijy91 on 2021/7/23.
//

extension NSEvent.ModifierFlags {
    public init(pluginModifiers: Array<String>) {
        self.init()
        if (pluginModifiers.contains("alt")) {
            insert(.option)
        }
        if (pluginModifiers.contains("capsLock")) {
            insert(.capsLock)
        }
        if (pluginModifiers.contains("control")) {
            insert(.control)
        }
        if (pluginModifiers.contains("fn")) {
            insert(.function)
        }
        if (pluginModifiers.contains("meta")) {
            insert(.command)
        }
        if (pluginModifiers.contains("shift")) {
            insert(.shift)
        }
    }
}
