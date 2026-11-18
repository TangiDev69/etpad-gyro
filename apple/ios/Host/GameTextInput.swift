// iPad software keyboard for ET's own text fields (profile name, chat,
// passwords, console). GPL-3.0-or-later.
import UIKit

final class GameTextInput: UIView, UIKeyInput, UITextInputTraits {
    var onCharacter:((UnicodeScalar)->Void)?
    var onKey:((Int32)->Void)?
    var autocorrectionType:UITextAutocorrectionType = .no
    var autocapitalizationType:UITextAutocapitalizationType = .none
    var spellCheckingType:UITextSpellCheckingType = .no
    var smartQuotesType:UITextSmartQuotesType = .no
    var smartDashesType:UITextSmartDashesType = .no
    var smartInsertDeleteType:UITextSmartInsertDeleteType = .no
    var keyboardType:UIKeyboardType = .asciiCapable
    var returnKeyType:UIReturnKeyType = .done
    var keyboardAppearance:UIKeyboardAppearance = .dark
    private let bar=UIView(frame:CGRect(x:0,y:0,width:100,height:48))
    private let label=UILabel()
    // Hardware keys already reach the game through SDL's GCKeyboard input.
    // While one is down, UIKit's copy of the same text is dropped; the
    // on-screen keyboard produces no UIPress events, so its text passes.
    private var hardwareKeysDown=0
    override func pressesBegan(_ presses:Set<UIPress>,with event:UIPressesEvent?) { hardwareKeysDown+=presses.filter { $0.key != nil }.count;super.pressesBegan(presses,with:event) }
    override func pressesEnded(_ presses:Set<UIPress>,with event:UIPressesEvent?) { hardwareKeysDown=max(0,hardwareKeysDown-presses.filter { $0.key != nil }.count);super.pressesEnded(presses,with:event) }
    override func pressesCancelled(_ presses:Set<UIPress>,with event:UIPressesEvent?) { hardwareKeysDown=0;super.pressesCancelled(presses,with:event) }
    // Mirrors the game field's text; empty shows a hint.
    func showPreview(_ text:String) {
        let value=text.isEmpty ? "Typing into the game":text
        if label.text != value { label.text=value;label.textColor=text.isEmpty ? ETPadTheme.cream.withAlphaComponent(0.6):ETPadTheme.cream }
    }
    override init(frame:CGRect) {
        super.init(frame:frame);isUserInteractionEnabled=false;isAccessibilityElement=false
        bar.backgroundColor=ETPadTheme.ink.withAlphaComponent(0.92)
        label.text="Typing into the game";label.font=UIFont.monospacedSystemFont(ofSize:16,weight:.semibold);label.textColor=ETPadTheme.cream
        label.lineBreakMode = .byTruncatingHead;label.textAlignment = .center
        label.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
        let cancel=UIButton(type:.system),done=UIButton(type:.system)
        cancel.setTitle("Cancel",for:.normal);done.setTitle("Done",for:.normal)
        cancel.tintColor=ETPadTheme.cream;done.tintColor=ETPadTheme.brass;done.titleLabel?.font=UIFont.systemFont(ofSize:17,weight:.bold)
        cancel.addAction(UIAction { [weak self] _ in self?.onKey?(27) },for:.touchUpInside)
        done.addAction(UIAction { [weak self] _ in self?.onKey?(13) },for:.touchUpInside)
        let row=UIStackView(arrangedSubviews:[cancel,label,done]);row.distribution = .fill;row.alignment = .center;row.spacing=16
        cancel.setContentHuggingPriority(.required,for:.horizontal);done.setContentHuggingPriority(.required,for:.horizontal)
        row.translatesAutoresizingMaskIntoConstraints=false;bar.addSubview(row)
        NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo:bar.leadingAnchor,constant:20),row.trailingAnchor.constraint(equalTo:bar.trailingAnchor,constant:-20),row.centerYAnchor.constraint(equalTo:bar.centerYAnchor)])
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    override var canBecomeFirstResponder:Bool { true }
    override var inputAccessoryView:UIView? { bar }
    // ET owns the text; always allow Delete so it reaches the field.
    var hasText:Bool { true }
    func insertText(_ text:String) {
        guard hardwareKeysDown==0 else { return }
        for scalar in text.unicodeScalars {
            if scalar == "\n" { onKey?(13) } else if !CharacterSet.controlCharacters.contains(scalar) { onCharacter?(scalar) }
        }
    }
    func deleteBackward() { if hardwareKeysDown==0 { onKey?(127) } }
}
