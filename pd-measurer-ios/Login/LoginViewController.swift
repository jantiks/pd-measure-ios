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
    @IBOutlet weak var loginContentView: UIView!
    @IBOutlet private weak var blurView: UIVisualEffectView!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var firstNameTF: UITextField!
    @IBOutlet private weak var lastNameTF: UITextField!
    @IBOutlet private weak var emailTF: UITextField!
    @IBOutlet private weak var wrongLabel: UILabel!
    @IBOutlet weak var loginCenterYConstraint: NSLayoutConstraint!
    
    private let offsetWhenKeyboardIsShowed: CGFloat = 200
    private let loginButtonDistanceToBlurView: CGFloat = 70
    private var startingBlurViewOrigin: CGPoint? = nil
    private var keyboardIsShowing = false
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initUi()
        initKeyboardObservers()
        setDelegates()
        hideKeyboardOnBackgroundTouched()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func getEmailBody() -> String? {
        if !textFieldsAreEmpty() {
            // text fields are not empty , so that the texts can be unwraped implictly.
            return Email(firstName: firstNameTF.text!, lastName: lastNameTF.text!, emailAddress: emailTF.text!).getEmailBody()
        }
        return nil
    }
    
    private func initKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func initUi() {
        loginContentView.layer.cornerRadius = 20
        blurView.layer.cornerRadius = 20
        loginButton.layer.cornerRadius = 10
        wrongLabel.isHidden = true

        [firstNameTF, lastNameTF, emailTF].forEach({ $0?.returnKeyType = .done })
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

        let window = UIApplication.shared.keyWindow
        let bottomPadding = window?.safeAreaInsets.bottom ?? 0.0
        
        if keyboardEndFrame.height > loginContentView.frame.origin.y + bottomPadding + loginButtonDistanceToBlurView && !keyboardIsShowing {
            loginCenterYConstraint.constant = loginContentView.frame.origin.y - bottomPadding + loginButtonDistanceToBlurView - keyboardEndFrame.height
        }
        
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.view.layoutIfNeeded()
        }
        
        keyboardIsShowing = true
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }

        loginCenterYConstraint.constant = -20
        
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.view.layoutIfNeeded()
        }
        
        keyboardIsShowing = false
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
        guard let emailBody = getEmailBody() else { return }
        
        if MFMailComposeViewController.canSendMail() {
            let mailVC = MFMailComposeViewController()
            mailVC.mailComposeDelegate = self
            mailVC.setToRecipients(["tigran.arsenyan.2015@gmail.com"])
            mailVC.setSubject("PD MEASUREMENTS")
            mailVC.setMessageBody(emailBody, isHTML: true)
            
            present(mailVC, animated: true)
        } else {
            showEmailFailureAlert()
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
    
    private func showEmailFailureAlert() {
        let ac = UIAlertController(title: "Email Error", message: "Couldn't send email message", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(ac, animated: true)
    }
}
