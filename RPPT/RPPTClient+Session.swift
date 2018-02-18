//
//  RPPTController+Session.swift
//  RPPT
//
//  Created by Andrew Finke on 12/5/17.
//  Copyright © 2017 aspin. All rights reserved.
//

import UIKit

extension RPPTClient {

    // MARK: - RPPTSessionManager

    // TODO: CHECK THREADS
    func setupSessionManager() {
        sessionManager.onSubscriberConnected = { [weak self] subscriberView in
            self?.onSubscriberConnected?(subscriberView)
        }

        sessionManager.onSessionError = { [weak self] error in
            self?.onOpenTokError?(error)
        }

        sessionManager.onPublisherError = { [weak self] error in
            self?.onOpenTokError?(error)
        }

        sessionManager.onSubscriberError = { [weak self] error, view in
            view?.removeFromSuperview()
            if let error = error {
                self?.onOpenTokError?(error)
            }
        }

    }

}
