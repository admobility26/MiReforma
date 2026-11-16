import Cocoa
import WebKit

@MainActor
final class ReformaApp: NSObject, NSApplicationDelegate, WKScriptMessageHandlerWithReply, WKUIDelegate {
    private var window: NSWindow!
    private var web: WKWebView!
    private var folder: URL?
    private let preferencesKey = "MiReforma.carpeta"
    private let filename = "registro_reforma.json"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        let messages = WKUserContentController()
        messages.addScriptMessageHandler(self, contentWorld: .page, name: "reforma")
        configuration.userContentController = messages
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        web = WKWebView(frame: .zero, configuration: configuration)
        web.uiDelegate = self

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1220, height: 830),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "Mi Reforma"
        window.minSize = NSSize(width: 760, height: 570)
        window.center()
        window.contentView = web
        configureMenu()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let url = Bundle.main.url(forResource: "mi_reforma", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            alert("No se encuentra la interfaz de Mi Reforma.")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func configureMenu() {
        let menu = NSMenu()
        let app = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Salir de Mi Reforma", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.submenu = appMenu
        menu.addItem(app)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: "Edición")
        editMenu.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }


    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alert(message)
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let dialog = NSAlert()
        dialog.messageText = "Mi Reforma"
        dialog.informativeText = message
        dialog.addButton(withTitle: "Confirmar")
        dialog.addButton(withTitle: "Cancelar")
        completionHandler(dialog.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let dialog = NSAlert()
        dialog.messageText = "Mi Reforma"
        dialog.informativeText = prompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 390, height: 25))
        field.stringValue = defaultText ?? ""
        dialog.accessoryView = field
        dialog.addButton(withTitle: "Aceptar")
        dialog.addButton(withTitle: "Cancelar")
        completionHandler(dialog.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)
    }

    private func alert(_ detail: String) {
        let a = NSAlert()
        a.messageText = "Mi Reforma"
        a.informativeText = detail
        a.runModal()
    }

    private func problem(_ detail: String) -> NSError {
        NSError(domain: "MiReforma", code: 1,
                userInfo: [NSLocalizedDescriptionKey: detail])
    }

    private func activeFolder() throws -> URL {
        guard let f = folder, FileManager.default.fileExists(atPath: f.path) else {
            throw problem("Selecciona primero una carpeta de la reforma.")
        }
        return f
    }

    private func ticketURL(_ name: String) throws -> URL {
        let allowed = #"^[A-Za-z0-9_-]+\.(pdf|png|jpg|jpeg|webp|heic|heif|gif|bmp|tiff)$"#
        guard name.range(of: allowed, options: [.regularExpression, .caseInsensitive]) != nil else {
            throw problem("El nombre del ticket no es válido.")
        }
        return try activeFolder().appendingPathComponent("tickets", isDirectory: true)
            .appendingPathComponent(name)
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame,
              let args = message.body as? [String: Any],
              let op = args["op"] as? String else {
            replyHandler(nil, "Solicitud no válida.")
            return
        }
        do {
            switch op {
            case "lastFolder":
                if let path = UserDefaults.standard.string(forKey: preferencesKey),
                   FileManager.default.fileExists(atPath: path) {
                    folder = URL(fileURLWithPath: path, isDirectory: true)
                    replyHandler(["name": folder!.lastPathComponent], nil)
                } else {
                    replyHandler(NSNull(), nil)
                }
            case "chooseFolder":
                let panel = NSOpenPanel()
                panel.title = "Seleccionar la carpeta de Mi Reforma"
                panel.message = "Aquí se guardarán registro_reforma.json y los tickets."
                panel.prompt = "Elegir carpeta"
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                panel.allowsMultipleSelection = false
                if let f = folder { panel.directoryURL = f }
                panel.begin { result in
                    if result == .OK, let selected = panel.url {
                        self.folder = selected
                        UserDefaults.standard.set(selected.path, forKey: self.preferencesKey)
                        replyHandler(["name": selected.lastPathComponent], nil)
                    } else {
                        replyHandler(NSNull(), nil)
                    }
                }
            case "loadData":
                let url = try activeFolder().appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: url.path) {
                    replyHandler(try String(contentsOf: url, encoding: .utf8), nil)
                } else {
                    replyHandler(NSNull(), nil)
                }
            case "saveData":
                guard let json = args["content"] as? String,
                      let bytes = json.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                      object["app"] as? String == "mi-reforma-chrome",
                      object["schema"] as? Int == 1 else {
                    throw problem("El registro no tiene un formato válido; no se ha sobrescrito.")
                }
                try json.write(to: activeFolder().appendingPathComponent(filename),
                               atomically: true, encoding: .utf8)
                replyHandler(true, nil)
            case "beginTicket":
                guard let name = args["name"] as? String else { throw problem("Falta el nombre del ticket.") }
                let destination = try ticketURL(name)
                let temp = destination.appendingPathExtension("part")
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destination.path) ||
                    FileManager.default.fileExists(atPath: temp.path) {
                    throw problem("Ya existe un ticket con ese nombre.")
                }
                guard FileManager.default.createFile(atPath: temp.path, contents: Data()) else {
                    throw problem("No se pudo preparar el ticket.")
                }
                replyHandler(true, nil)
            case "ticketChunk":
                guard let name = args["name"] as? String,
                      let b64 = args["base64"] as? String,
                      b64.utf8.count < 450_000,
                      let bytes = Data(base64Encoded: b64) else { throw problem("El fragmento de ticket no es válido.") }
                let temp = try ticketURL(name).appendingPathExtension("part")
                let handle = try FileHandle(forWritingTo: temp)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: bytes)
                replyHandler(true, nil)
            case "finishTicket":
                guard let name = args["name"] as? String else { throw problem("Falta el nombre del ticket.") }
                let destination = try ticketURL(name)
                try FileManager.default.moveItem(at: destination.appendingPathExtension("part"), to: destination)
                replyHandler(true, nil)
            case "removeTicket":
                guard let name = args["name"] as? String else { throw problem("Falta el nombre del ticket.") }
                let destination = try ticketURL(name)
                for path in [destination, destination.appendingPathExtension("part")] {
                    if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
                }
                replyHandler(true, nil)
            case "openTicket":
                guard let name = args["name"] as? String else { throw problem("Falta el nombre del ticket.") }
                let url = try ticketURL(name)
                guard FileManager.default.fileExists(atPath: url.path) else { throw problem("No se encuentra ese ticket.") }
                NSWorkspace.shared.open(url)
                replyHandler(true, nil)
            case "exportCSV":
                guard let content = args["content"] as? String else { throw problem("CSV vacío.") }
                let panel = NSSavePanel()
                panel.nameFieldStringValue = "gastos_reforma.csv"
                panel.begin { result in
                    if result == .OK, let url = panel.url {
                        do { try content.write(to: url, atomically: true, encoding: .utf8); replyHandler(true, nil) }
                        catch { replyHandler(nil, error.localizedDescription) }
                    } else { replyHandler(false, nil) }
                }
            default:
                replyHandler(nil, "Operación no reconocida.")
            }
        } catch {
            replyHandler(nil, error.localizedDescription)
        }
    }
}

@main
struct MiReformaMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = ReformaApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
