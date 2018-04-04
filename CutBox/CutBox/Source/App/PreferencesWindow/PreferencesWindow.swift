//
//  PreferencesWindow.swift
//  CutBox
//
//  Created by Jason on 31/3/18.
//  Copyright © 2018 ocodo. All rights reserved.
//

import Cocoa
import KeyHolder
import Magnet
import RxSwift
import ServiceManagement

extension PreferencesWindow: RecordViewDelegate {

    func recordView(_ recordView: RecordView, canRecordKeyCombo keyCombo: KeyCombo) -> Bool {
        return true
    }
    
    func recordViewShouldBeginRecording(_ recordView: RecordView) -> Bool {
        HotKeyCenter
            .shared
            .unregisterHotKey(with: searchKeyComboUserDefaults)
        return true
    }
    
    func recordView(_ recordView: RecordView, didChangeKeyCombo keyCombo: KeyCombo) {
        switch recordView {
        case keyRecorder:
            hotKeyService
                .searchKeyCombo
                .onNext(keyCombo)
        default: break
        }
    }
    
    func recordViewDidClearShortcut(_ recordView: RecordView) {
        
    }
    
    func recordViewDidEndRecording(_ recordView: RecordView) {
        if HotKeyCenter.shared.hotKey(searchKeyComboUserDefaults) == nil {
            hotKeyService.resetDefaultGlobalToggle()
        }
    }
}

class PreferencesWindow: NSWindow {

    let searchKeyComboUserDefaults = Constants.searchKeyComboUserDefaults
    let hotKeyService = HotKeyService.shared

    let disposeBag = DisposeBag()

    @IBOutlet weak var keyRecorder: RecordView!

    override func awakeFromNib() {
        self.titlebarAppearsTransparent = true

        keyRecorder.delegate = self

        hotKeyService
            .searchKeyCombo
            .subscribe(onNext: { self.keyRecorder.keyCombo = $0 })
            .disposed(by: disposeBag)
    }

    @IBAction func setAutoLogin(sender: NSButton) {
        let appBundleIdentifier = "info.ocodo.CutBoxHelper" as CFString
        let autoLogin = (sender.state == .on)
        if SMLoginItemSetEnabled(appBundleIdentifier, autoLogin) {
            NSLog("Successfully \(autoLogin ? "added" : "removed") login item.")
        } else {
            NSLog("Failed to configure login item \(appBundleIdentifier).")
        }
    }
}
