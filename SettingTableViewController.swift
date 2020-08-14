//
//  SettingTableViewController.swift
//  Extr
//
//  Created by Jongmin Lee on 2/7/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//

import UIKit
import CoreData
import StoreKit
import MessageUI

class SettingTableViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    @IBOutlet weak var resetSwitch: UISwitch!
    
    var userInput:UITextField?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()

    }
    @IBAction func resetAction(_ sender: UISwitch) {
        if resetSwitch.isOn{
            
            let alert = UIAlertController(title: "Reset", message: "Are you sure to delete all data?", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: deleteData)
            let cancelAction = UIAlertAction(title: "cancel", style: .default, handler: nil)
            alert.addAction(okAction)
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
            
            resetSwitch.isOn = false
        }
    }
    
    func deleteData(alert:UIAlertAction){
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        request.includesPropertyValues = false
        do{
            let items = try context.fetch(request)
            for item in items{
                context.delete(item)
            }
            ManageData.shared.transactionVC.items = []
            let alert = UIAlertController(title: "Reset", message: "All data is deleted", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            
        } catch {
            print("Fetch deleting error\(error)")
        }
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath == [0,0]{
            if #available(iOS 10.3, *) {
                SKStoreReviewController.requestReview()
            } else if let url = URL(string: "itms-apps://itunes.apple.com/app/id1497482833") {
                UIApplication.shared.openURL(url)
            }
        } else if indexPath == [0,1]{
            sendMail()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    // MARK:- sending feedback / email
    
    func sendMail(){
        let alert = UIAlertController(title: "Help and Feedback report", message: "This message will be sent to the developer.", preferredStyle: .alert)
        let sendAction = UIAlertAction(title: "Send", style: .default, handler: sendHandler)
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        alert.addTextField(configurationHandler: userInputField)
        alert.addAction(sendAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    func userInputField(textField: UITextField!){
        userInput = textField
        userInput?.placeholder = "e.g.) rate function doesn't work"
        userInput?.keyboardType = UIKeyboardType.emailAddress
    }
    
    func sendHandler(alert:UIAlertAction){
        let mailView = mailComposeControl()
        if MFMailComposeViewController.canSendMail(){
            self.present(mailView, animated: true, completion: nil)
        }else{
            sendMailError()
        }
    }
    
    func sendMailError(){
        let sendErrorAlert = UIAlertController(title: "Error", message: "You must have an active mail account on your device.", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        sendErrorAlert.addAction(alertAction)
        present(sendErrorAlert, animated: true, completion: nil)
    }
    
    func mailComposeControl() -> MFMailComposeViewController{
        let userEmailAddress = "tltmzmaos@gmail.com"
        let mail = MFMailComposeViewController()
        
        let mailBody = (userInput?.text)!
        mail.mailComposeDelegate = self as MFMailComposeViewControllerDelegate
        mail.setToRecipients([userEmailAddress])
        mail.setSubject("[Let's track] Help and Feedback")
        mail.setMessageBody(mailBody, isHTML: false)
        return mail
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }

}
