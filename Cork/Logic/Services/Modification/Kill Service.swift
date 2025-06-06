//
//  Kill Service.swift
//  Cork
//
//  Created by David Bureš on 13.05.2024.
//

import Foundation
import CorkShared

extension ServicesTracker
{
    func killService(_ serviceToKill: HomebrewService, servicesState: ServicesState, serviceModificationProgress: ServiceModificationProgress) async
    {
        for await output in shell(AppConstants.shared.brewExecutablePath, ["services", "kill", serviceToKill.name])
        {
            switch output
            {
            case .standardOutput(let outputLine):
                AppConstants.shared.logger.debug("Service killing output: \(outputLine)")
            case .standardError(let errorLine):
                AppConstants.shared.logger.error("Service killing error: \(errorLine)")
            }
        }

        do
        {
            serviceModificationProgress.progress = 5.0

            try await synchronizeServices(preserveIDs: true)
        }
        catch let servicesSynchronizationError
        {
            AppConstants.shared.logger.error("Could not synchronize services: \(servicesSynchronizationError.localizedDescription)")

            servicesState.showError(.couldNotSynchronizeServices(errorThrown: servicesSynchronizationError.localizedDescription))
        }
    }
}
