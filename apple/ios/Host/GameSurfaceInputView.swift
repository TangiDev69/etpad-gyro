// Render-only SDL window: native unclaimed surface touches own menu pointers.
// Adapted from UTP GameViewController.swift at a9313911efcf044fd66f9a679af53e55e255a8b4.
// GPL-3.0-or-later.
import UIKit
final class GameSurfaceInputView:UIView {
    var pointer:((CGPoint,Int32)->Void)?
    override init(frame:CGRect){
        super.init(frame:frame);isMultipleTouchEnabled=false;isOpaque=false;backgroundColor = .clear
        addGestureRecognizer(UIHoverGestureRecognizer(target:self,action:#selector(hover(_:))))
    }
    required init?(coder:NSCoder){fatalError("init(coder:)")}
    private func normalized(_ p:CGPoint)->CGPoint { CGPoint(x:max(0,min(1,p.x/max(1,bounds.width))),y:max(0,min(1,p.y/max(1,bounds.height)))) }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?){if let t=touches.first { pointer?(normalized(t.location(in:self)),1) }}
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?){if let t=touches.first { pointer?(normalized(t.location(in:self)),-1) }}
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?){if let t=touches.first { pointer?(normalized(t.location(in:self)),0) }}
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){touchesEnded(touches,with:event)}
    @objc private func hover(_ gesture:UIHoverGestureRecognizer){pointer?(normalized(gesture.location(in:self)),-1)}
}
