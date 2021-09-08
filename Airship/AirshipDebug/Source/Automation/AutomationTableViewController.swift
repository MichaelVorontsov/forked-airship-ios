/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(Airship)
import Airship
#endif


/**
 * The AutomationCell represents a single IAA schedule in the table.
 */
class AutomationCell: UITableViewCell {
    @IBOutlet weak var messageType: UILabel!
    @IBOutlet weak var messageName: UILabel!
    @IBOutlet weak var messageID: UILabel!

    var schedule : UASchedule?

    func setCellTheme() {
        backgroundColor = ThemeManager.shared.currentTheme.Background
        messageName.textColor = ThemeManager.shared.currentTheme.PrimaryText
        messageID.textColor = ThemeManager.shared.currentTheme.SecondaryText
        messageType.textColor = ThemeManager.shared.currentTheme.WidgetTint
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setCellTheme()
    }
}

/**
 * The AutomationTableViewController displays a list of IAA schedules
 * for debugging use.
 */
class AutomationTableViewController: UITableViewController {
    var launchPathComponents : [String]?
    var launchCompletionHandler : (() -> Void)?
    private var schedules : Array<UASchedule>?

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshInAppAutomation), for: UIControl.Event.valueChanged)
        self.refreshControl = refreshControl
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = ThemeManager.shared.currentTheme.Background;

        setTableViewTheme()
        refreshInAppAutomation()
    }

    @objc private func refreshInAppAutomation() {
        InAppAutomation.shared.getSchedules({ (schedulesFromAutomation) in
            self.schedules = schedulesFromAutomation
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        })
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.schedules?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.shared.currentTheme.WidgetTint
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AutomationCell", for: indexPath) as! AutomationCell

        // clear cell
        cell.schedule = nil
        cell.messageType.text = nil
        cell.messageName.text = nil
        cell.messageID.text = nil
        cell.backgroundColor = nil

        if let schedule = self.schedules?[indexPath.row] {
            cell.schedule = schedule
            if let inAppMessage = schedule as? InAppMessageSchedule {
                let message = inAppMessage.message
                
                switch (message.displayContent.displayType) {
                case .banner:
                    cell.messageType.text = "B"
                case .fullScreen:
                    cell.messageType.text = "F"
                case .modal:
                    cell.messageType.text = "M"
                case .HTML:
                    cell.messageType.text = "H"
                case .custom:
                    cell.messageType.text = "C"
                @unknown default:
                    break
                }
                cell.messageName.text = message.name
            } else if schedule is ActionSchedule {
                cell.messageType.text = "A"
                cell.messageName.text = "Action"
            } else if schedule is DeferredSchedule {
                cell.messageType.text = "D"
                cell.messageName.text = "Deferred"
            }
            
            cell.messageID.text = schedule.identifier
            if (schedule.isValid) {
                cell.backgroundColor = nil
            } else {
                cell.backgroundColor = UIColor.red
            }
        }

        return cell
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        case AutomationDetailViewController.segueID:
            guard let automationDetailViewController = segue.destination as? AutomationDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            guard let selectedAutomationCell = sender as? AutomationCell else {
                fatalError("Unexpected sender: \(sender ?? "unknown sender")")
            }

            automationDetailViewController.schedule = selectedAutomationCell.schedule
        default:
            print("ERROR: Unexpected Segue Identifier; \(segue.identifier ?? "unknown identifier")")
        }
    }

}

