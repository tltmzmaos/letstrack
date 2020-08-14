//
//  FirstViewController.swift
//  Extr
//
//  Created by Jongmin Lee on 1/25/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//

import UIKit
import CoreData
import Charts
import MessageUI

class OverviewViewController: UIViewController, MFMailComposeViewControllerDelegate{
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var userInput:UITextField?

    var items = [ExpenseEntity]()
    var totalExpense = 0.0

    //MARK:- PieChart data
    @IBOutlet weak var pieChart: PieChartView!
    var numOfData = [PieChartDataEntry]()
    var colors = [UIColor(named: "food"),UIColor(named: "shopping"),UIColor(named: "entertainment"),UIColor(named: "education"),UIColor(named: "transportation"),UIColor(named: "utility"),UIColor(named: "housing"),UIColor(named: "car"),UIColor(named: "other")]
    var foodEntry = PieChartDataEntry(value: 0, label: "Food")
    var shoppingEntry = PieChartDataEntry(value: 0, label: "Shopping")
    var entertainmentEntry = PieChartDataEntry(value: 0, label: "Entertainment")
    var educationEntry = PieChartDataEntry(value: 0, label: "Education")
    var transportationEntry = PieChartDataEntry(value: 0, label: "Transportation")
    var utilityEntry = PieChartDataEntry(value: 0, label: "Utility and Bill")
    var housingEntry = PieChartDataEntry(value: 0, label: "Housing")
    var carEntry = PieChartDataEntry(value: 0, label: "Car")
    var otherEntry = PieChartDataEntry(value: 0.0, label: "Other")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pieChart.chartDescription?.text = "percentage"
        numOfData = []
        loadItems()
        updateData()
        
    }
    //MARK:- Sending email
    @IBAction func sendEmailPressed(_ sender: UIBarButtonItem) {

        let alert = UIAlertController(title: "Monthly report", message: "Enter an email address to send your expense report of current month.", preferredStyle: .alert)
        let sendAction = UIAlertAction(title: "Send", style: .default, handler: sendHandler)
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        alert.addTextField(configurationHandler: userInputField)
        alert.addAction(sendAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    func userInputField(textField: UITextField!){
        userInput = textField
        userInput?.placeholder = "example@example.com"
        userInput?.keyboardType = UIKeyboardType.emailAddress
    }
    
    func sendHandler(alert: UIAlertAction){
        let mailView = mailComposeControl()
        if MFMailComposeViewController.canSendMail(){
            self.present(mailView, animated: true, completion: nil)
        }else{
            sendMailError()
        }
    }
    
    func mailComposeControl() -> MFMailComposeViewController{
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let mailSubject = formatter.string(from: date)
        let userEmailAddress = userInput!.text!
        let mail = MFMailComposeViewController()
        
        let mailBody = summarizeMonthlyExpense()
        mail.mailComposeDelegate = self as MFMailComposeViewControllerDelegate
        mail.setToRecipients([userEmailAddress])
        mail.setSubject("["+mailSubject+"]"+" Monthly expense report")
        mail.setMessageBody(mailBody, isHTML: false)
        return mail
    }
    
    func sendMailError(){
        let sendErrorAlert = UIAlertController(title: "Error", message: "You must have an active mail account on your device.", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        sendErrorAlert.addAction(alertAction)
        present(sendErrorAlert, animated: true, completion: nil)
    }
        
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func summarizeMonthlyExpense() -> String{
        var food = 0.0
        var shopping = 0.0
        var entertainment = 0.0
        var education = 0.0
        var transportation = 0.0
        var utility = 0.0
        var housing = 0.0
        var car = 0.0
        var other = 0.0
        var monthTotal = 0.0
        
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: date)
        
        var foodNote = "\n"
        var shopNote = "\n"
        var enterNote = "\n"
        var eduNote = "\n"
        var tranNote = "\n"
        var utilNote = "\n"
        var houseNote = "\n"
        var carNote = "\n"
        var otherNote = "\n"
        
        for i in items{
            if formatter.string(from: i.date!) == month{
                monthTotal += i.amount
                if i.category == "Food"{
                    food += i.amount
                    if i.note != ""{
                        foodNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Shopping"{
                    shopping += i.amount
                    if i.note != ""{
                        shopNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Entertainment"{
                    entertainment += i.amount
                    if i.note != ""{
                        enterNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Education"{
                    education += i.amount
                    if i.note != ""{
                        eduNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Transportation"{
                    transportation += i.amount
                    if i.note != ""{
                        tranNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Utility and Bill"{
                    utility += i.amount
                    if i.note != ""{
                        utilNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Housing"{
                    housing += i.amount
                    if i.note != ""{
                        houseNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Car"{
                    car += i.amount
                    if i.note != ""{
                        carNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                } else if i.category == "Other"{
                    other += i.amount
                    if i.note != ""{
                        otherNote += i.note! + " : " + String(i.amount) + "\n"
                    }
                }
            }
        }
        
        let monthTotalStr = "Total expense : $"+String(monthTotal)+"\n\n"
        let foodStr = "- Food : " + String(food) + foodNote + "\n"
        let shoppingStr = "- Shopping : " + String(shopping) + shopNote + "\n"
        let enterStr = "- Entertainment : " + String(entertainment) + enterNote + "\n"
        let eduStr = "- Education : " + String(education) + eduNote + "\n"
        let transStr = "- Transportation : " + String(transportation) + tranNote + "\n"
        let utilStr = "- Utility and Bill : " + String(utility) + utilNote + "\n"
        let houseStr = "- Housing : " + String(housing) + houseNote + "\n"
        let carStr = "- Car : " + String(car) + carNote + "\n"
        let otherStr = "- Other : " + String(other) + otherNote + "\n"
        
        let returnStr = monthTotalStr+foodStr+shoppingStr+enterStr+eduStr+transStr+utilStr+houseStr+carStr+otherStr
        return returnStr
    }
    
    //MARK:- Pie Chart
    
    func updateData(){
        numOfData = [PieChartDataEntry]()
        foodEntry.value = 0.0
        shoppingEntry.value = 0.0
        entertainmentEntry.value = 0.0
        educationEntry.value = 0.0
        transportationEntry.value = 0.0
        utilityEntry.value = 0.0
        housingEntry.value = 0.0
        carEntry.value = 0.0
        otherEntry.value = 0.0
        
        let categories = ["Food","Shopping","Entertainment","Education","Transportation","Utility and Bill","Housing","Car","Other"]
        var expenseOfCategory = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        
        for i in items{
            if i.category == "Food"{
                expenseOfCategory[0] += i.amount
            } else if i.category == "Shopping"{
                expenseOfCategory[1] += i.amount
            } else if i.category == "Entertainment"{
                expenseOfCategory[2] += i.amount
            } else if i.category == "Education"{
                expenseOfCategory[3] += i.amount
            } else if i.category == "Transportation"{
                expenseOfCategory[4] += i.amount
            } else if i.category == "Utility and Bill"{
                expenseOfCategory[5] += i.amount
            } else if i.category == "Housing"{
                expenseOfCategory[6] += i.amount
            } else if i.category == "Car"{
                expenseOfCategory[7] += i.amount
            }  else if i.category == "Other"{
                expenseOfCategory[8] += i.amount
            }
        }
                
        for i in 0..<expenseOfCategory.count{
            if expenseOfCategory[i] > 0{
                if categories[i] == "Food"{
                    foodEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(foodEntry) == false{
                        numOfData.append(foodEntry)
                    }
                }else if categories[i] == "Shopping"{
                    shoppingEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(shoppingEntry) == false{
                        numOfData.append(shoppingEntry)
                    }
                }else if categories[i] == "Entertainment"{
                    entertainmentEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(entertainmentEntry) == false{
                        numOfData.append(entertainmentEntry)
                    }
                }else if categories[i] == "Education"{
                    educationEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(educationEntry) == false{
                        numOfData.append(educationEntry)
                    }
                }else if categories[i] == "Transportation"{
                    transportationEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(transportationEntry) == false{
                        numOfData.append(transportationEntry)
                    }
                }else if categories[i] == "Utility and Bill"{
                    utilityEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(utilityEntry) == false{
                        numOfData.append(utilityEntry)
                    }
                }else if categories[i] == "Housing"{
                    housingEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(housingEntry) == false{
                        numOfData.append(housingEntry)
                    }
                }else if categories[i] == "Car"{
                    carEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(carEntry) == false{
                        numOfData.append(carEntry)
                    }
                }else if categories[i] == "Other"{
                    otherEntry.value = (expenseOfCategory[i]/totalExpense)*100
                    if numOfData.contains(otherEntry) == false{
                        numOfData.append(otherEntry)
                    }
                }
            }
        }
        calBalance()
        
    }
    
    func updateChart(){
        let dataSet = PieChartDataSet(entries: numOfData, label: nil)
        let chartData = PieChartData(dataSet: dataSet)
        dataSet.colors = colors as! [NSUIColor]
        pieChart.data = chartData
        pieChart.legend.textColor = .black
        pieChart.centerText = "Total Expense\n$"+String(totalExpense)
    }
    
    func calBalance(){
        var tempTotal = 0.0
        for i in items{
            tempTotal += i.amount
        }
        totalExpense = tempTotal
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadItems()
        calBalance()
        updateData()
        updateChart()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.enableAllOrientation = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadItems()
        calBalance()
        updateData()
        updateChart()
    }
    
    func loadItems(){
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        let sort = NSSortDescriptor(key: "date", ascending: false)
        request.sortDescriptors = [sort]
        do {
            items = try context.fetch(request)
        } catch {
            print("Error fetching data \(error)")
        }
    }
    
    //MARK:- calendar
    
    @IBAction func calendarButtonPressed(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "calendarView", sender: self)
    }
    
}


