import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var host: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: keyboard())
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 300),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        self.host = host
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        host?.rootView = keyboard()
    }

    private func keyboard() -> KeyboardView {
        let entries = KeyboardSnapshot.url().map { KeyboardSnapshot.read(from: $0) } ?? []
        return KeyboardView(entries: entries, insert: { [weak self] in
            self?.textDocumentProxy.insertText($0)
        }, next: { [weak self] in self?.advanceToNextInputMode() })
    }
}
