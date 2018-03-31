//
//  CutBoxController.swift
//  CutBox
//
//  Created by Jason Milkins on 17/3/18.
//  Copyright © 2018 ocodo. All rights reserved.
//

// Central controller object, binds things together
// and runs the status item

import Cocoa
import RxSwift
import RxCocoa
import HotKey

class CutBoxController: NSObject {

    let popupController: PopupController
    let pasteboardService: PasteboardService
    let searchView: SearchView
    var screen: NSScreen
    var width: CGFloat
    var height: CGFloat
    let disposeBag = DisposeBag()

    @IBOutlet weak var statusMenu: NSMenu!

    let hotKey = HotKey(key: .v, modifiers: [.shift, .command])

    let statusItem: NSStatusItem = NSStatusBar
        .system
        .statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        guard let mainScreen = NSScreen.main else {
            fatalError("Unable to get main screen")
        }

        self.pasteboardService = PasteboardService()
        self.pasteboardService.startTimer()
        self.screen = mainScreen
        self.width = self.screen.frame.width / 1.8
        self.height = self.screen.frame.height / 1.8

        // TODO: Refactor: Hook up search view to pasteboard service so it can implement the table delegate/datasource
        self.searchView = SearchView.fromNib() ?? SearchView()

        self.popupController = PopupController(
            content: self.searchView
        )

        super.init()

        setupSearchTextEventBindings()
        setupSearchViewAndFilterBinding()
        setupPopup()
        setupHotkey()
    }

    func pasteSelectedClipToPasteboard() {
        guard let selectedClip = self
            .pasteboardService[
                self.searchView
                .clipboardItemsTable
                .selectedRow
            ]

            else { return }

        pasteToPasteboard(selectedClip)
    }

    func pasteTopClipToPasteboard() {
        guard let topClip = self.pasteboardService[0]
            else { return }
        pasteToPasteboard(topClip)
    }

    private func pasteToPasteboard(_ clip: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clip, forType: .string)
    }

    @objc func hideApp() {
        NSApp.hide(self)
    }

    @objc func fakePaste() {
        FakeKey.send(UInt16(9), useCommandFlag: true)
    }

    @IBAction func searchClicked(_ sender: NSMenuItem) {
        popupController.togglePopup()
    }

    @IBAction func quitClicked(_ sender:  NSMenuItem) {
        pasteboardService.saveToDefaults()
        NSApplication.shared.terminate(self)
    }

    @IBAction func clearHistoryClicked(_ sender: NSMenuItem) {
        pasteboardService.clear()
    }

    private func closeAndPaste() {
        self.pasteSelectedClipToPasteboard()
        self.popupController.closePopup()
        perform(#selector(hideApp), with: self, afterDelay: 0.1)
        perform(#selector(fakePaste), with: self, afterDelay: 0.25)
    }

    override func awakeFromNib() {
        let icon = #imageLiteral(resourceName: "statusIcon") // invisible on dark xcode source theme
        icon.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = statusMenu

        setupAboutItem()
    }

    private func itemSelectUp() {
        self.searchView.itemSelectUp()
    }

    private func itemSelectDown() {
        self.searchView.itemSelectDown()
    }

    private func resetSearchText() {
        self.searchView.searchText.string = ""
        self.searchView.filterText.onNext("")
        self.searchView.clipboardItemsTable.reloadData()
    }

    private func setupAboutItem() {
        let aboutTitle = "About CutBox"
        let aboutItem = NSMenuItem()
        aboutItem.title = aboutTitle

        self.statusMenu.addItem(aboutItem)

        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] else {
            return
        }

        aboutItem.title = aboutTitle + " \(String(describing: version))"
    }

    private func setupSearchViewAndFilterBinding() {
        self.searchView.clipboardItemsTable.dataSource = self
        self.searchView.clipboardItemsTable.delegate = self

        self.searchView.filterText
            .bind {
                self.popupController.resizePopup(height: self.height)
                self.pasteboardService.filterText = $0
                self.searchView.clipboardItemsTable.reloadData()
            }
            .disposed(by: self.disposeBag)
    }

    private func setupSearchTextEventBindings() {
        self.searchView
            .events
            .bind { event in
                switch event {
                case .closeAndPaste:
                    self.closeAndPaste()
                case .itemSelectUp:
                    self.itemSelectUp()
                case .itemSelectDown:
                    self.itemSelectDown()
                }
            }
            .disposed(by: disposeBag)
    }

    private func setupHotkey() {
        self.hotKey.keyDownHandler = self.popupController.togglePopup
    }

    private func setupPopup() {
        self.popupController
            .backgroundView
            .backgroundColor = CutBoxPreferences.shared.searchViewBackgroundColor

        self.popupController
            .backgroundView
            .alphaValue = CutBoxPreferences.shared.searchViewBackgroundAlpha

        self.popupController
            .resizePopup(width: self.width,
                         height: self.height)

        self.popupController
            .didOpenPopup = {
                self.popupController
                    .resizePopup(width: self.width,
                                 height: self.height)

                self.resetSearchText()
                self.searchView
                    .searchText
                    .window?
                    .makeFirstResponder(self.searchView.searchText)
        }

        self.popupController
            .willClosePopup = {
                self.resetSearchText()
        }
    }
}
