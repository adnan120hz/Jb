//
//  AltIconTableViewController.swift
//  Sileo
//
//  Created by Amy on 21/03/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit
import Evander

struct AltIcon {
    var displayName: String
    var author: String
    var key: String?
    var image: UIImage
}

class AltIconTableViewController: UITableViewController {
    
    public static let IconUpdate = Notification.Name("AlternateIconUpdate")
    
    public class func altImage(_ name: String) -> UIImage {
        #if targetEnvironment(macCatalyst)
        let path = Bundle.main.bundleURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("AppIcon.icns")
        #else
        let path = Bundle.main.bundleURL.appendingPathComponent(name + "@2x.png")
        #endif
        return UIImage(contentsOfFile: path.path) ?? UIImage()
    }
    
    // Sileo demo (userland): only the stock green icon
    var icons = [
        AltIcon(displayName: "Stock", author: "Dennis Bednarz", key: nil, image: altImage("AppIcon60x60")),
    ]
    
    @objc func updateSileoColors() {
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateSileoColors()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = String(localizationKey: "Alternate_Icon_Title")
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.rowHeight = 75
                
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        icons.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = AltIconTableViewCell()
        cell.altIcon = icons[indexPath.row]
        if UIApplication.shared.alternateIconName == cell.altIcon?.key {
            cell.accessoryType = .checkmark
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let altIcon = icons[indexPath.row]
        UIApplication.shared.setAlternateIconName(altIcon.key) { error in
            print("Failed to set icon with error \(error?.localizedDescription ?? "Unknown Error")")
        }
        NotificationCenter.default.post(name: AltIconTableViewController.IconUpdate, object: nil)
        self.tableView.reloadRows(at: self.tableView.indexPathsForVisibleRows ?? [IndexPath](), with: .none)
    }

}
