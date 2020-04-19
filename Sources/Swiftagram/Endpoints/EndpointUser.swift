//
//  EndpointUser.swift
//  Swiftagram
//
//  Created by Stefano Bertagno on 08/03/2020.
//

import Foundation

import ComposableRequest

public extension Endpoint {
    /// A `struct` holding reference to `users` `Endpoint`s. Requires authentication.
    struct User {
        /// The base endpoint.
        private static let base = Endpoint.version1.users.defaultHeader()

        // MARK: Info
        /// A list of all profiles blocked by the user.
        public static let blocked = base.locking(authenticator: \.header).blocked_list

        /// A user matching `identifier`'s info.
        /// - parameter identifier: A `String` holding reference to a valid user identifier.
        public static func summary(for identifier: String) -> Lock<Request> {
            return base.locking(authenticator: \.header).append(identifier).info
        }

        /// All user matching `query`.
        /// - parameter query: A `String` holding reference to a valid user query.
        public static func all(matching query: String) -> Paginated<Lock<Request>, Response> {
            return base.locking(authenticator: \.header).search.query("q", value: query).paginating()
        }

        // MARK: Actions
        /// Report the user matching `identifier`.
        /// - parameter identifier: A `String` holding reference to a valid user identifier.
        public static func report(_ identifier: String) -> Lock<Request> {
            return base.append(identifier).flag_user
                .locking {
                    guard let secret = $0.key as? Secret else {
                        fatalError("A `Swiftagram.Secret` is required to authenticate `.report`.")
                    }
                    return $0.request.header(secret.header)
                        .body("_csrftoken", value: secret.crossSiteRequestForgery.value)
                        .body("_uuid", value: Device.default.deviceGUID.uuidString)
                        .body("_uid", value: secret.identifier)
                        .body("user_id", value: identifier)
                        .body("source_name", value: "profile")
                        .body("is_spam", value: "true")
                        .body("reason_id", value: "1")
                    }
        }
    }
}