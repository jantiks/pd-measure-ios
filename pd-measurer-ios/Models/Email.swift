//
//  Email.swift
//  pd-measurer-ios
//
//  Created by Tigran Arsenyan on 9/26/21.
//

import Foundation

struct Email {
    private let firstName: String
    private let lastName: String
    private let emailAddress: String
    
    init(firstName: String, lastName: String, emailAddress: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.emailAddress = emailAddress
    }
    
    func getEmailBody() -> String {
        return """
                <p>First name: \(firstName)</p>
                <p>Last name: \(lastName)</p>
                <p>Email address: \(emailAddress)</p>
                """
    }
}
