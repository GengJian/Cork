//
//  Maintenance Finished View.swift
//  Cork
//
//  Created by David Bureš on 04.10.2023.
//

import CorkShared
import SwiftUI

struct MaintenanceFinishedView: View
{
    @AppStorage("displayOnlyIntentionallyInstalledPackagesByDefault") var displayOnlyIntentionallyInstalledPackagesByDefault: Bool = true

    @Environment(\.dismiss) var dismiss: DismissAction

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var brewData: BrewDataStorage

    @EnvironmentObject var cachedDownloadsTracker: CachedPackagesTracker

    @EnvironmentObject var outdatedPackageTacker: OutdatedPackageTracker

    let shouldUninstallOrphans: Bool
    let shouldPurgeCache: Bool
    let shouldDeleteDownloads: Bool
    let shouldPerformHealthCheck: Bool

    let packagesHoldingBackCachePurge: [String]

    let numberOfOrphansRemoved: Int
    let reclaimedSpaceAfterCachePurge: Int

    let brewHealthCheckFoundNoProblems: Bool

    @Binding var maintenanceFoundNoProblems: Bool

    var displayablePackagesHoldingBackCachePurge: [String]
    {
        // See if the user wants to see all packages, or just those that are installed manually
        // If they only want to see those installed manually, only show those that are holding back cache purge that are actually only installed manually

        if displayOnlyIntentionallyInstalledPackagesByDefault
        {
            /// This abomination of a variable does the following:
            /// 1. Filter out only packages that were installed intentionally
            /// 2. Get the names of the packages that were installed intentionally
            /// 3. Get only the names of packages that were installed intentionally, and are also holding back cache purge
            /// **Motivation**: When the user only wants to see packages they have installed intentionally, they will be confused if a dependency suddenly shows up here
            // let intentionallyInstalledPackagesHoldingBackCachePurge: [String] = brewData.installedFormulae.filter({ $0.installedIntentionally }).map({ $0.name }).filter{packagesHoldingBackCachePurge.contains($0)}

            /// **Motivation**: Same as above, but more performant
            /// Instead of looking through all packages, it only looks through packages that are outdated. Since only outdated packages can hold back purging, it kills two birds with one stone
            /// Process:
            /// 1. Get only the names of outdated packages
            /// 2. Get only the names of packages that are outdated, and are holding back cache purge
            // let intentionallyInstalledPackagesHoldingBackCachePurge: [String] = outdatedPackageTacker.outdatedPackages.map(\.package.name).filter({ packagesHoldingBackCachePurge.contains($0) })

            /// **Motivation**: Same as above, but even more performant
            /// Only formulae can hold back cache purging. Therefore, we just filter out the outdated formulae, and those must be holding back the purging
            return outdatedPackageTacker.displayableOutdatedPackages.filter { $0.package.type == .formula }.map(\.package.name)
        }
        else
        {
            return packagesHoldingBackCachePurge
        }
    }

    var body: some View
    {
        ComplexWithIcon(systemName: "checkmark.seal")
        {
            VStack(alignment: .leading, spacing: 5)
            {
                Text("maintenance.finished")
                    .font(.headline)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                if shouldUninstallOrphans
                {
                    Text("maintenance.results.orphans-count-\(numberOfOrphansRemoved)")
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if shouldPurgeCache
                {
                    VStack(alignment: .leading)
                    {
                        Text("maintenance.results.package-cache")
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        if !displayablePackagesHoldingBackCachePurge.isEmpty
                        {
                            if displayablePackagesHoldingBackCachePurge.count >= 3
                            {
                                let packageNamesNotTruncated: [String] = Array(displayablePackagesHoldingBackCachePurge.prefix(3))

                                let numberOfTruncatedPackages: Int = displayablePackagesHoldingBackCachePurge.count - packageNamesNotTruncated.count

                                Text("maintenance.results.package-cache.skipped-\(packageNamesNotTruncated.formatted(.list(type: .and)))-and-\(numberOfTruncatedPackages)-others")
                                    .font(.caption)
                                    .foregroundColor(Color(nsColor: NSColor.systemGray))
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            else
                            {
                                Text("maintenance.results.package-cache.skipped-\(displayablePackagesHoldingBackCachePurge.formatted(.list(type: .and)))")
                                    .font(.caption)
                                    .foregroundColor(Color(nsColor: NSColor.systemGray))
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        /*
                         if cachePurgingSkippedPackagesDueToMostRecentVersionsNotBeingInstalled
                         {
                         if packagesHoldingBackCachePurgeTracker.count > 2
                         {

                         Text("maintenance.results.package-cache.skipped-\(packagesHoldingBackCachePurgeTracker[0...1].joined(separator: ", "))-and-\(packagesHoldingBackCachePurgeTracker.count - 2)-others")
                         .font(.caption)
                         .foregroundColor(Color(nsColor: NSColor.systemGray))

                         }
                         else
                         {
                         Text("maintenance.results.package-cache.skipped-\(packagesHoldingBackCachePurgeTracker.joined(separator: ", "))")
                         .font(.caption)
                         .foregroundColor(Color(nsColor: NSColor.systemGray))
                         }
                         }
                         */
                    }
                }

                if shouldDeleteDownloads
                {
                    VStack(alignment: .leading)
                    {
                        Text("maintenance.results.cached-downloads")
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("maintenance.results.cached-downloads.summary-\(reclaimedSpaceAfterCachePurge.formatted(.byteCount(style: .file)))")
                            .font(.caption)
                            .foregroundColor(Color(nsColor: NSColor.systemGray))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if shouldPerformHealthCheck
                {
                    if brewHealthCheckFoundNoProblems
                    {
                        Text("maintenance.results.health-check.problems-none")
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    else
                    {
                        Text("maintenance.results.health-check.problems")
                            .onAppear
                            {
                                maintenanceFoundNoProblems = false
                            }
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .task
        {
            do
            {
                try await brewData.synchronizeInstalledPackages(cachedPackagesTracker: cachedDownloadsTracker)
            }
            catch let synchronizationError
            {
                appState.showAlert(errorToShow: .couldNotSynchronizePackages(error: synchronizationError.localizedDescription))
            }
        }
    }
}
