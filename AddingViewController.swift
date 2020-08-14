//
//  AddingViewController.swift
//  Extr
//
//  Created by Jongmin Lee on 1/25/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//


import UIKit
import CoreData

class AddingViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    

    
    @IBOutlet weak var amountField: UITextField!
    @IBOutlet weak var notesField: UITextField!
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var items = [ExpenseEntity]()
    
    @IBOutlet weak var pickerView: UIPickerView!
    let pickerData = ["Food","Shopping","Entertainment","Education","Transportation","Utility and Bill","Housing","Car","Other"]
    var expenseCategory = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.amountField.delegate = self
        notesField.delegate = self
        self.doneButton()
        notesField.returnKeyType = UIReturnKeyType.done
        pickerView.setValue(UIColor.black, forKey: "textColor")

    }

    
    func saveItems(){
        do{
            try context.save()
            ManageData.shared.transactionVC.items = items
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
    
    //MARK:- Button Methods
    @IBAction func addButtonPressed(_ sender: UIButton) {
        loadItems()
        if let temp = Double(amountField.text!){
            if temp <= 0.0{
                let alert = UIAlertController(title: "Warning", message: "The amount is correct?\n"+amountField.text!, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                present(alert, animated: true, completion: nil)
            } else {
                let newExpense = ExpenseEntity(context: context)
                newExpense.amount = temp
                newExpense.date = Date()
                newExpense.note = notesField.text!
                if expenseCategory == ""{
                    expenseCategory = "Other"
                }
                newExpense.category = expenseCategory
                        //newExpense.amount = Double(amountField.text!)!
            
                items.insert(newExpense, at: 0)
                saveItems()
                ManageData.shared.transactionVC.tableView.reloadData()
                dismiss(animated: true, completion: nil)
            }
        } else {
            if amountField.text == ""{
                let alert = UIAlertController(title: "Warning", message: "You must enter the amount.", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    present(alert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Warning", message: "Enter a vaild number.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(okAction)
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
    
    func doneButton(){
        let keyboard = UIToolbar()
        keyboard.sizeToFit()
        let spaces = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
        keyboard.items = [spaces, doneButton]
        self.amountField.inputAccessoryView = keyboard
    }
    
    @IBAction func doneButtonPressed(_ sender: UIButton){
        self.amountField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    
    //MARK:- PickerView helper methods
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
        expenseCategory = pickerData[row]
    }
}


//MARK:- Border design extension

@IBDesignable
class DesignableView: UIView {
}

@IBDesignable
class DesignableButton: UIButton {
}

@IBDesignable
class DesignableLabel: UILabel {
}

extension UIView {
    
    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    
    @IBInspectable
    var borderColor: UIColor? {
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.borderColor = color.cgColor
            } else {
                layer.borderColor = nil
            }
        }
    }
    
    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }
    
    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }
    
    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }
    
    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }
}


