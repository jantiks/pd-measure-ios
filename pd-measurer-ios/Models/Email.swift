//
//  Email.swift
//  pd-measurer-ios
//
//  Created by Tigran Arsenyan on 9/26/21.
//

import Foundation

class Email {
    
    private var firstName: String?
    private var lastName: String?
    private var emailAddress: String?
    private var farPD: String?
    private var nearPD: String?
    private var leftSH: String?
    private var rightSH: String?
    
    func setFirstName(_ name: String?) {
        firstName = name
    }
    
    func setLastName(_ name: String?) {
        lastName = name
    }
    
    func setEmailAddress(_ emailAddress: String?) {
        self.emailAddress = emailAddress
    }
    
    func setFarPD(_ pd: Float?) {
        farPD = pd == nil ? nil: "\(pd!)"
    }
    
    func setNearPD(_ pd: Float?) {
        nearPD = pd == nil ? nil: "\(pd!)"
    }
    
    func setLeftSH(_ sh: Float?) {
        leftSH = sh == nil ? nil: "\(sh!)"
    }
    
    func setRightSH(_ sh: Float?) {
        rightSH = sh == nil ? nil: "\(sh!)"
    }
    
    func getEmailBody() -> String {
        return """
                First name: \(firstName ?? "N/A")
                Last name: \(lastName ?? "N/A")
                Email address: \(emailAddress ?? "N/A")
                Far PD: \(farPD ?? "N/A")
                Near PD: \(nearPD ?? "N/A")
                Left SH: \(leftSH ?? "N/A")
                Right SH: \(rightSH ?? "N/A")
                """
    }
}
