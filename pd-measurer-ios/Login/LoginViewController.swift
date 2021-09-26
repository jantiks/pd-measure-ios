//
//  LoginViewController.swift
//  pd-measurer-ios
//
//  Created by Tigran Arsenyan on 9/23/21.
//

import UIKit
import MessageUI

class LoginViewController: UIViewController {
    
    // MARK: IBOutlets
    @IBOutlet private weak var blurView: UIVisualEffectView!
    @IBOutlet private weak var loginContentView: UIView!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var firstNameTF: UITextField!
    @IBOutlet private weak var lastNameTF: UITextField!
    @IBOutlet private weak var emailTF: UITextField!
    @IBOutlet private weak var wrongLabel: UILabel!
    
    private let offsetWhenKeyboardIsShowed: CGFloat = 200
    private var startingBlurViewOrigin: CGPoint? = nil
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("worked")
        initUi()
        initKeyboardObservers()
        setDelegates()
        hideKeyboardOnBackgroundTouched()
    }
    
    private func initKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func initUi() {
        loginContentView.layer.cornerRadius = 20
        blurView.layer.cornerRadius = 20
//        loginButton.layer.cornerRadius = 10
//        wrongLabel.isHidden = true
//
//        [firstNameTF, lastNameTF, emailTF].forEach({ $0?.returnKeyType = .done })
    }
    
    private func setDelegates() {
        [firstNameTF, lastNameTF, emailTF].forEach({ $0?.delegate = self })
    }
    
    /*
     checking if textfields are empty , if so then make the wrong label to appear
     */
    private func textFieldsAreEmpty() -> Bool {
        if firstNameTF.text?.isEmpty == true ||
            lastNameTF.text?.isEmpty == true ||
            emailTF.text?.isEmpty == true {
            
            wrongLabel.isHidden = false
            return true
        }
        
        wrongLabel.isHidden = true
        return false
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
            let keyboardEndFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        startingBlurViewOrigin = blurView.frame.origin

        let window = UIApplication.shared.keyWindow
        let bottomPadding = window?.safeAreaInsets.bottom ?? 0.0 // This is the key
        if keyboardEndFrame.height > blurView.frame.minY + offsetWhenKeyboardIsShowed {
            blurView.frame.origin.y = blurView.frame.minY + offsetWhenKeyboardIsShowed + bottomPadding - keyboardEndFrame.height
        }
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }

        if let origin = startingBlurViewOrigin {
            blurView.frame.origin.y = origin.y
        }
        
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }
    
    
    // MARK: IBActions
    @IBAction func loginAction(_ sender: UIButton) {
        if !textFieldsAreEmpty() {
            // send email action
            sendEmail()
            print("EMAIL ACTION")
        }
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension LoginViewController: MFMailComposeViewControllerDelegate {
    func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["tigran.arsenyan.2015@gmail.com"])
            mail.setMessageBody("<p>You're so awesome!</p>", isHTML: true)
            
            present(mail, animated: true)
        } else {
            // show failure alert
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
