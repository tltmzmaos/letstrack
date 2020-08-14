//
//  CalendarViewController.swift
//  Extr
//
//  Created by Jongmin Lee on 2/6/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//

import UIKit
import FSCalendar
import CoreData

class CalendarViewController: UIViewController, FSCalendarDelegate, FSCalendarDataSource, UITableViewDelegate, UITableViewDataSource {
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    @IBOutlet weak var calendar: FSCalendar!
    @IBOutlet weak var tableView: UITableView!
    var items = [ExpenseEntity]()
    var dateItems = [ExpenseEntity]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        calendar.delegate = self
        calendar.dataSource = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.register(UINib(nibName: "TableViewCell", bundle: nil), forCellReuseIdentifier: "reuseCell")
        loadItems()
        initialSetup()
        
        // Do any additional setup after loading the view.
    }
    func initialSetup(){
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.enableAllOrientation = false
        calendar.appearance.headerTitleColor = .blue
        calendar.appearance.weekdayTextColor = .darkGray
        let todayDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        loadItems()
        for i in items{
            if dateFormatter.string(for: todayDate) == dateFormatter.string(for: i.date){
                dateItems.append(i)
            }
        }
        tableView.reloadData()
    }
    
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var numOfEvent = 0
        for i in items{
            if dateFormatter.string(for: i.date) == dateFormatter.string(for: date){
                numOfEvent += 1
            }
        }
        return numOfEvent
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        dateItems = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for i in items{
            if dateFormatter.string(for: i.date) == dateFormatter.string(for: date){
                dateItems.append(i)
            }
        }
        tableView.reloadData()
    }
    
    
    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
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
    
    //MARK:- table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dateItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseCell", for: indexPath) as! TableViewCell
        cell.amount.text = "$"+String(format: "%0.2f", dateItems[indexPath.row].amount)
        cell.notes.text = dateItems[indexPath.row].note
        if dateItems[indexPath.row].category == "Food"{
            cell.category.image = UIImage(named: "foodIcon")
        } else if dateItems[indexPath.row].category == "Education"{
            cell.category.image = UIImage(named: "educationIcon")
        } else if dateItems[indexPath.row].category == "Shopping"{
            cell.category.image = UIImage(named: "shoppingIcon")
        } else if dateItems[indexPath.row].category == "Entertainment"{
            cell.category.image = UIImage(named: "entertainmentIcon")
        } else if dateItems[indexPath.row].category == "Transportation"{
            cell.category.image = UIImage(named: "transportationIcon")
        } else if dateItems[indexPath.row].category == "Utility and Bill"{
            cell.category.image = UIImage(named: "utilityIcon")
        } else if dateItems[indexPath.row].category == "Housing"{
            cell.category.image = UIImage(named: "housingIcon")
        } else if dateItems[indexPath.row].category == "Car"{
            cell.category.image = UIImage(named: "carIcon")
        } else if dateItems[indexPath.row].category == "Other"{
            cell.category.image = UIImage(named: "otherIcon")
        }
        cell.categoryL.text = dateItems[indexPath.row].category

        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
}
