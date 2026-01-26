//
//  KeychainHelper.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/23/26.
//

import Foundation
import Security

class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}

    func save(_ data: Data, service: String, account: String) {
        let query = [kSecValueData: data, kSecClass: kSecClassGenericPassword,
                     kSecAttrService: service, kSecAttrAccount: account] as CFDictionary
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }

    func read(service: String, account: String) -> Data? {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                     kSecAttrAccount: account, kSecReturnData: true] as CFDictionary
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        return result as? Data
    }
}
