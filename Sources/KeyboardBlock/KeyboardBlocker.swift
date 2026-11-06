import CoreGraphics
import Foundation

/// Bloqueia a entrada do teclado criando um `CGEventTap` no nível da sessão e
/// descartando os eventos.
///
/// Propriedade de segurança importante: o tap vive dentro deste processo. Se o
/// app travar, for morto ou chamar `stop()`, o teclado volta ao normal
/// imediatamente — não existe estado persistente no sistema.
final class KeyboardBlocker {

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    /// `NX_SYSDEFINED`: mídia, brilho, volume. Não tem case em `CGEventType`,
    /// então vai pelo valor cru — o mask só precisa do bit.
    private static let systemDefinedRaw: UInt32 = 14

    private static let blockedEventTypes: [UInt32] = [
        CGEventType.keyDown.rawValue,
        CGEventType.keyUp.rawValue,
        CGEventType.flagsChanged.rawValue, // caps lock, cmd/opt/ctrl/shift
        systemDefinedRaw,
    ]

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = Self.blockedEventTypes.reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1)
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        tap = newTap

        if let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: newTap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        guard tap != nil else { return }

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        tap = nil
        runLoopSource = nil
        isRunning = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // O sistema desativa o tap se nosso callback demorar demais.
        // Reativamos para não liberar o teclado sem querer.
        if type.rawValue == CGEventType.tapDisabledByTimeout.rawValue
            || type.rawValue == CGEventType.tapDisabledByUserInput.rawValue {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Descartar o evento: nada chega ao sistema.
        return nil
    }
}

private let keyboardTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue()
    return blocker.handle(type: type, event: event)
}
