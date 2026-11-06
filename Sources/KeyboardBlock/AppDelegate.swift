import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private enum DefaultsKey {
        static let duration = "autoUnlockSeconds"
    }

    private enum UnlockReason {
        case manual
        case timeout
        case escapeGesture
    }

    private let blocker = KeyboardBlocker()
    private var statusItem: NSStatusItem!

    /// Sempre limitado: nunca existe "bloquear para sempre".
    /// Se o app morrer, o teclado volta; se não morrer, o timer devolve.
    private let durations: [TimeInterval] = [60, 120, 300, 600]
    private var selectedDuration: TimeInterval = 120

    private var deadline: Date?
    private var countdownTimer: Timer?
    private var rightHoldTimer: Timer?

    private var isBlocked: Bool { blocker.isRunning }

    // MARK: - Ciclo de vida

    func applicationDidFinishLaunching(_ notification: Notification) {
        let stored = UserDefaults.standard.double(forKey: DefaultsKey.duration)
        if durations.contains(stored) {
            selectedDuration = stored
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        installEscapeGesture()
        updateAppearance()
    }

    func applicationWillTerminate(_ notification: Notification) {
        blocker.stop()
    }

    // MARK: - Ações

    @objc private func lockNow() {
        guard ensureAccessibility() else { return }

        guard blocker.start() else {
            showAlert(
                title: "Não consegui bloquear o teclado",
                message: """
                O sistema recusou a criação do event tap.

                Verifique se o KeyboardBlock está ativado em Ajustes do Sistema › \
                Privacidade e Segurança › Acessibilidade e reabra o app.
                """
            )
            return
        }

        deadline = Date().addingTimeInterval(selectedDuration)
        startCountdown()
        updateAppearance()
    }

    private func unlock(reason: UnlockReason) {
        guard isBlocked else { return }

        blocker.stop()
        countdownTimer?.invalidate()
        countdownTimer = nil
        deadline = nil
        updateAppearance()

        // Evita que o gesto de escape dispare um clique fantasma no app em foco.
        if case .escapeGesture = reason {
            NSSound.beep()
        }
    }

    @objc private func unlockNow() {
        unlock(reason: .manual)
    }

    @objc private func quit() {
        blocker.stop()
        NSApp.terminate(nil)
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        selectedDuration = seconds
        UserDefaults.standard.set(seconds, forKey: DefaultsKey.duration)

        if isBlocked {
            deadline = Date().addingTimeInterval(seconds)
            updateAppearance()
        }
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(
                title: "Não consegui alterar o início automático",
                message: """
                \(error.localizedDescription)

                Dica: copie o KeyboardBlock.app para /Applications antes de ativar esta opção.
                """
            )
        }
        refreshMenu()
    }

    // MARK: - Permissão de Acessibilidade

    private func ensureAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = "Acessibilidade necessária"
        alert.informativeText = """
        O KeyboardBlock precisa da permissão de Acessibilidade para interceptar o teclado.

        1. Em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade, ative o KeyboardBlock.
        2. Feche e reabra o app.

        Depois clique em "Bloquear teclado" novamente.
        """
        alert.addButton(withTitle: "Abrir Ajustes")
        alert.addButton(withTitle: "Agora não")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
        return false
    }

    // MARK: - Contagem regressiva

    private func startCountdown() {
        countdownTimer?.invalidate()

        // `.common` mantém o timer rodando com o menu aberto (modo eventTracking).
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let deadline = self.deadline else { return }
            if deadline.timeIntervalSinceNow <= 0 {
                self.unlock(reason: .timeout)
            } else {
                self.updateAppearance()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func countdownText() -> String {
        guard let deadline else { return "" }
        let remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    // MARK: - Saída de emergência

    /// Segurar o botão direito por 1,5s libera o teclado.
    /// Funciona mesmo com a barra de menus escondida (app em tela cheia),
    /// e não depende do teclado — que é justamente o que está bloqueado.
    private func installEscapeGesture() {
        NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] _ in
            guard let self, self.isBlocked else { return }
            self.rightHoldTimer?.invalidate()
            self.rightHoldTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.unlock(reason: .escapeGesture)
            }
        }

        NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseUp]) { [weak self] _ in
            self?.rightHoldTimer?.invalidate()
            self?.rightHoldTimer = nil
        }
    }

    // MARK: - Aparência

    private func updateAppearance() {
        guard let button = statusItem.button else { return }

        let symbol = isBlocked ? "keyboard.fill" : "keyboard"
        let description = isBlocked ? "Teclado bloqueado" : "Teclado liberado"

        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description) {
            if isBlocked {
                image.isTemplate = false
                button.image = image.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(paletteColors: [.systemRed])
                ) ?? image
            } else {
                image.isTemplate = true
                button.image = image
            }
        } else {
            button.title = isBlocked ? "BLQ" : "KB"
        }

        button.imagePosition = .imageLeading
        button.title = isBlocked ? " " + countdownText() : ""
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        if isBlocked {
            let header = NSMenuItem(
                title: "Bloqueado · \(countdownText())",
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(item("Liberar agora", #selector(unlockNow)))

            let hint = NSMenuItem(
                title: "Atalho de emergência: segure o botão direito por 1,5s",
                action: nil,
                keyEquivalent: ""
            )
            hint.isEnabled = false
            menu.addItem(hint)
        } else {
            menu.addItem(item("Bloquear teclado", #selector(lockNow)))
        }

        menu.addItem(.separator())

        let durationItem = NSMenuItem(title: "Liberar sozinho em", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for seconds in durations {
            let entry = NSMenuItem(
                title: label(for: seconds),
                action: #selector(selectDuration(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.representedObject = seconds
            entry.state = (seconds == selectedDuration) ? .on : .off
            submenu.addItem(entry)
        }
        durationItem.submenu = submenu
        menu.addItem(durationItem)

        menu.addItem(.separator())
        menu.addItem(item("Abrir Ajustes de Acessibilidade", #selector(openAccessibilitySettings)))

        let login = item("Iniciar no login", #selector(toggleLoginItem))
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Sair", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        if !key.isEmpty {
            entry.keyEquivalentModifierMask = .command
        }
        return entry
    }

    private func label(for seconds: TimeInterval) -> String {
        switch seconds {
        case 60: return "1 minuto"
        case 120: return "2 minutos"
        case 300: return "5 minutos"
        default: return "\(Int(seconds / 60)) minutos"
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
