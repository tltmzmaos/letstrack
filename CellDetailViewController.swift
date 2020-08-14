//
//  CellDetailViewController.swift
//  Extr
//
//  Created by Jongmin Lee on 2/3/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//

import UIKit
import CoreData

class CellDetailViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UITextViewDelegate {

    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var items = [ExpenseEntity]()
    var newItems = [ExpenseEntity]()
    var item:ExpenseEntity?
    var selectedRow = 0

    @IBOutlet weak var expenseText: UITextView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var categoryPicker: UIPickerView!
    @IBOutlet weak var noteText: UITextView!
    
    let pickerData = ["Food","Shopping","Entertainment","Education","Transportation","Utility and Bill","Housing","Car","Other"]
    
    var newAmount = 0.0
    var newCategory = ""
    var newDate = Date()
    var newNote = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        categoryPicker.dataSource = self
        categoryPicker.delegate = self
        noteText.delegate = self
        expenseText.delegate = self
        noteText.returnKeyType = .done
        self.doneButton()
        loadItems()
        basicSetup()

    }
    
    func basicSetup(){
        selectedRow = ManageData.shared.transactionVC.selectedRow
        item = items[selectedRow]
        noteText.borderColor = .darkGray
        noteText.cornerRadius = 10
        categoryPicker.setValue(UIColor.black, forKey: "textColor")
        categoryPicker.setValue(UIColor.gray, forKey: "magnifierLineColor")

        datePicker.setValue(UIColor.black, forKey: "textColor")
        datePicker.setValue(false, forKey: "highlightsToday")
        datePicker.setValue(UIColor.gray, forKey: "magnifierLineColor")

        switch item!.category {
        case "Food":
            categoryPicker.selectRow(0, inComponent: 0, animated: true)
            newCategory = pickerData[0]
        case "Shopping":
            categoryPicker.selectRow(1, inComponent: 0, animated: true)
            newCategory = pickerData[1]
        case "Entertainment":
            categoryPicker.selectRow(2, inComponent: 0, animated: true)
            newCategory = pickerData[2]
        case "Education":
            categoryPicker.selectRow(3, inComponent: 0, animated: true)
            newCategory = pickerData[3]
        case "Transportation":
            categoryPicker.selectRow(4, inComponent: 0, animated: true)
            newCategory = pickerData[4]
        case "Utility and Bill":
            categoryPicker.selectRow(5, inComponent: 0, animated: true)
            newCategory = pickerData[5]
        case "Housing":
            categoryPicker.selectRow(6, inComponent: 0, animated: true)
            newCategory = pickerData[6]
        case "Car":
            categoryPicker.selectRow(7, inComponent: 0, animated: true)
            newCategory = pickerData[7]
        case "Other":
            categoryPicker.selectRow(8, inComponent: 0, animated: true)
            newCategory = pickerData[8]
        default:
            categoryPicker.selectRow(0, inComponent: 0, animated: true)
            newCategory = pickerData[0]
        }
        newDate = item!.date!
        datePicker.date = item!.date!
        newNote = item!.note!
        noteText.text = item!.note!
        newAmount = item!.amount
        expenseText.text = String(format: "%0.2f", item!.amount)
    }
    
    func getInputs() -> Bool{
        if let temp = Double(expenseText.text!){
            if temp <= 0.0 {
                let alert = UIAlertController(title: "Warning", message: "The amount is correct?\n"+expenseText.text!, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                present(alert, animated: true, completion: nil)
                return false
            }else{
                newAmount = temp
                newDate = datePicker.date
                newNote = noteText.text
                return true
            }
        }else{
            if expenseText.text == ""{
                let alert = UIAlertController(title: "Warning", message: "You must enter the amount.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                present(alert, animated: true, completion: nil)
                return false
            }else{
                let alert = UIAlertController(title: "Warning", message: "Enter a vaild number.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                present(alert, animated: true, completion: nil)
                return false
            }
        }
    }
    
    func saveNewInputs(){
        item?.amount = newAmount
        item?.category = newCategory
        item?.date = newDate
        item?.note = newNote
        
        items[selectedRow] = item!
        newItems = items.sorted(by: { $0.date! > $1.date!})
        saveItems()
    }
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        if getInputs() == true{
            saveNewInputs()
            ManageData.shared.transactionVC.tableView.reloadData()
            dismiss(animated: true, completion: nil)
        }
    }
    
    func saveItems(){
        do{
            try context.save()
            ManageData.shared.transactionVC.items = newItems
        } catch {
            print("Saving context error. \(error)")
        }

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
    
    func doneButton(){
        let keyboard = UIToolbar()
        keyboard.sizeToFit()
        let spaces = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonsPressed))
        keyboard.items = [spaces, doneButton]
        self.expenseText.inputAccessoryView = keyboard
    }
    
    @IBAction func doneButtonsPressed(_ sender: UIButton){
        self.expenseText.resignFirstResponder()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n"{
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView == noteText{
            self.view.frame.origin.y -= 150
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == noteText{
            self.view.frame.origin.y = 0
        }
    }

    //MARK:- picker view
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        newCategory = pickerData[row]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.enableAllOrientation = false
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.enableAllOrientation = true
            
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }

}
