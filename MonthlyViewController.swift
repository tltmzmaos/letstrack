//
//  MonthlyViewController.swift
//  Extr
//
//  Created by Jongmin Lee on 2/6/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//

import UIKit
import CoreData
import Charts

class MonthlyViewController: UIViewController, ChartViewDelegate {
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var items = [ExpenseEntity]()
    
    @IBOutlet weak var barChart: BarChartView!
    @IBOutlet weak var segment: UISegmentedControl!
    var selectedYear = ""
    
    var colors = [UIColor(named: "food"),UIColor(named: "shopping"),UIColor(named: "entertainment"),UIColor(named: "education"),UIColor(named: "transportation"),UIColor(named: "utility"),UIColor(named: "housing"),UIColor(named: "car"),UIColor(named: "other")]
    
    var jan = BarChartDataEntry(x: 0, y: 0)
    var feb = BarChartDataEntry(x: 1, y: 0)
    var mar = BarChartDataEntry(x: 2, y: 0)
    var apr = BarChartDataEntry(x: 3, y: 0)
    var may = BarChartDataEntry(x: 4, y: 0)
    var jun = BarChartDataEntry(x: 5, y: 0)
    var jul = BarChartDataEntry(x: 6, y: 0)
    var aug = BarChartDataEntry(x: 7, y: 0)
    var sep = BarChartDataEntry(x: 8, y: 0)
    var oct = BarChartDataEntry(x: 9, y: 0)
    var nov = BarChartDataEntry(x: 10, y: 0)
    var dec = BarChartDataEntry(x: 11, y: 0)
    
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Sep", "Nov", "Dec"]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barChart.delegate = self
        loadItems()
        setInitialYear()
        segSetup()
        getValues(year: selectedYear)
        setBarChart()
    }
    override func viewWillAppear(_ animated: Bool) {
        loadItems()
        setInitialYear()
        segSetup()
        getValues(year: selectedYear)
        setBarChart()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadItems()
        setInitialYear()
        segSetup()
        getValues(year: selectedYear)
        setBarChart()
    }
    
    func setInitialYear(){
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        selectedYear = formatter.string(from: date)
    }
    
    func setBarChart(){
        
        barChart.noDataText = "No data available"
        barChart.xAxis.labelCount = 12
        barChart.xAxis.labelPosition = .bottom

        var dataEntries: [BarChartDataEntry] = []
        
        dataEntries.append(jan)
        dataEntries.append(feb)
        dataEntries.append(mar)
        dataEntries.append(apr)
        dataEntries.append(may)
        dataEntries.append(jun)
        dataEntries.append(jul)
        dataEntries.append(aug)
        dataEntries.append(sep)
        dataEntries.append(oct)
        dataEntries.append(nov)
        dataEntries.append(dec)
        

        
        let charDataSet = BarChartDataSet(entries: dataEntries, label: nil)
        let chartData = BarChartData()
        chartData.addDataSet(charDataSet)
        chartData.setDrawValues(true)
        barChart.drawValueAboveBarEnabled = true
        barChart.xAxis.valueFormatter = IndexAxisValueFormatter(values: months)
        barChart.xAxis.granularityEnabled = true
        barChart.xAxis.drawGridLinesEnabled = false
        barChart.scaleYEnabled = true
        barChart.scaleXEnabled = true
        barChart.xAxis.granularity = 1.0
        barChart.data = chartData
        charDataSet.colors = colors as! [NSUIColor]
        barChart.animate(xAxisDuration: 2.0, yAxisDuration: 2.0)
        barChart.setVisibleXRange(minXRange: 3, maxXRange: 12)
        barChart.leftAxis.spaceBottom = 0.0
        barChart.rightAxis.spaceBottom = 0.0
        barChart.legend.enabled = false
        barChart.leftAxis.drawLabelsEnabled = false
        
    }
    
    func getValues(year: String){
        jan.y = 0
        feb.y = 0
        mar.y = 0
        apr.y = 0
        jun.y = 0
        jul.y = 0
        aug.y = 0
        sep.y = 0
        oct.y = 0
        nov.y = 0
        dec.y = 0
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        for i in items{
            let tempTime = formatter.string(from: i.date!)
            if tempTime == year+"-01"{
                jan.y += i.amount
            } else if tempTime == year+"-02"{
                feb.y += i.amount
            } else if tempTime == year+"-03"{
                mar.y += i.amount
            } else if tempTime == year+"-04"{
                apr.y += i.amount
            } else if tempTime == year+"-05"{
                may.y += i.amount
            } else if tempTime == year+"-06"{
                jun.y += i.amount
            } else if tempTime == year+"-07"{
                jul.y += i.amount
            } else if tempTime == year+"-08"{
                aug.y += i.amount
            } else if tempTime == year+"-09"{
                sep.y += i.amount
            } else if tempTime == year+"-10"{
                oct.y += i.amount
            } else if tempTime == year+"-11"{
                nov.y += i.amount
            } else if tempTime == year+"-12"{
                dec.y += i.amount
            }
            
        }
    }
    
    func segSetup(){
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        var tempList = [String]()
        for i in items{
            let tempYear = formatter.string(from: i.date!)
            if tempList.contains(tempYear) == false{
                tempList.append(tempYear)
            }
        }
        segment.replaceSeg(segments: tempList)
    }
    
    @IBAction func segChange(_ sender: UISegmentedControl) {
        let tempYear = segment.titleForSegment(at: segment.selectedSegmentIndex)!
        getValues(year: tempYear)
        setBarChart()
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
    
    
}

//MARK:- Segment extension

extension UISegmentedControl{
    func replaceSeg(segments: [String]){
        self.removeAllSegments()
        for i in segments{
            self.insertSegment(withTitle: i, at: self.numberOfSegments, animated: true)
        }
    }
}
