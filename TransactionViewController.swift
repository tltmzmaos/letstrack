//
//  SecondViewController.swift
//  Extr
//
//  Created by Jongmin Lee on 1/25/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//

import UIKit
import CoreData

class ManageData {
    static let shared = ManageData()
    var transactionVC = TransactionViewController()
}

class TransactionViewController: UIViewController, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var items = [ExpenseEntity]()
    var selectedRow = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "TableViewCell", bundle: nil), forCellReuseIdentifier: "reuseCell")
        ManageData.shared.transactionVC = self
        tableView.tableFooterView = UIView()
        
        loadItems()
        tableView.reloadData()
    }

    @IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "adding", sender: self)
    }
}


//MARK:- Extension for search bar
extension TransactionViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchBar.text != ""{
            let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
            let categoryPredicate = NSPredicate(format: "ANY category CONTAINS[c] %@", searchBar.text!)
            let notePredicate = NSPredicate(format: "ANY note CONTAINS[c] %@", searchBar.text!)
            
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [categoryPredicate, notePredicate])
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            loadItems(request: request)
            tableView.reloadData()
            
        }
        DispatchQueue.main.async {
            searchBar.resignFirstResponder()
        }
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text?.count == 0{
            loadItems()
            tableView.reloadData()
            DispatchQueue.main.async {
                searchBar.resignFirstResponder()
            }
        }
    }
}

//MARK:- Extension for tableView

extension TransactionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseCell", for: indexPath) as! TableViewCell
        cell.amount.text = "$"+String(format: "%0.2f", items[indexPath.row].amount)
        cell.notes.text = items[indexPath.row].note
        if items[indexPath.row].category == "Food"{
            cell.category.image = UIImage(named: "foodIcon")
        } else if items[indexPath.row].category == "Education"{
            cell.category.image = UIImage(named: "educationIcon")
        } else if items[indexPath.row].category == "Shopping"{
            cell.category.image = UIImage(named: "shoppingIcon")
        } else if items[indexPath.row].category == "Entertainment"{
            cell.category.image = UIImage(named: "entertainmentIcon")
        } else if items[indexPath.row].category == "Transportation"{
            cell.category.image = UIImage(named: "transportationIcon")
        } else if items[indexPath.row].category == "Utility and Bill"{
            cell.category.image = UIImage(named: "utilityIcon")
        } else if items[indexPath.row].category == "Housing"{
            cell.category.image = UIImage(named: "housingIcon")
        } else if items[indexPath.row].category == "Car"{
            cell.category.image = UIImage(named: "carIcon")
        } else if items[indexPath.row].category == "Other"{
            cell.category.image = UIImage(named: "otherIcon")
        }
        cell.categoryL.text = items[indexPath.row].category

        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath){
        if(editingStyle == .delete){
            context.delete(items[indexPath.row])
            items.remove(at: indexPath.row)
            saveItems()
            self.tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        performSegue(withIdentifier: "cellDetail", sender: self)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadItems()
        self.tableView.reloadData()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.enableAllOrientation = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadItems()
        self.tableView.reloadData()
    }
    
    func saveItems(){
        do{
            try context.save()
        } catch {
            print("Saving context error. \(error)")
        }
        self.tableView.reloadData()
    }
    
    func loadItems(){
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        do {
            items = try context.fetch(request)
        } catch {
            print("Error fetching data \(error)")
        }
    }
    
    func loadItems(request: NSFetchRequest<ExpenseEntity>){
        do {
            items = try context.fetch(request)
        } catch {
            print("Error fetching data \(error)")
        }
    }
}


