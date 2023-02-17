//
//  ViewController.swift
//  MKReminderUtil
//
//  Created by MorganWang  on 2021/5/13.
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate {

    // MARK: properties
    
    @IBOutlet weak var titleTF: UITextField!
    @IBOutlet weak var addressTF: UITextField!
    @IBOutlet weak var noteTF: UITextField!
    @IBOutlet weak var timeTF: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!
    
    // MARK: view life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setupUI()
    }
    
    
    // MARK: init
    fileprivate func setupUI() {
        title = "添加日历提醒"
        self.datePicker.isHidden = true
    }
        
    // MARK: utils
    
    
    // MARK: action
    
    @IBAction func pickerDateTime(_ sender: Any) {
        self.datePicker?.isHidden = false
    }
    
    @IBAction func dateChanged(_ sender: Any) {
        let date = self.datePicker?.date
        let dateStr = Date.string(from: date, formatterStr: "yyyy-MM-dd HH:mm:ss")
        timeTF.text = dateStr
    }
    
    @IBAction func addByMondayToFriday(_ sender: Any) {
        let title = titleTF.text ?? ""
        let address = addressTF.text
        let notes = noteTF.text
        let time = timeTF.text ?? ""
        
        if time.count == 0 {
            print("请先设置日期")
            return
        }
        MKCalendarReminderUtil.util.addEvent(title, location: address, notes: notes, timeStr: time, eventKey: title)
    }
    
    
    @IBAction func addByNationalWorkRule(_ sender: Any) {
        let title = titleTF.text ?? ""
        let address = addressTF.text
        let notes = noteTF.text
        let time = timeTF.text ?? ""
        
        if time.count == 0 {
            print("请先设置日期")
            return
        }
        
        MKCalendarReminderUtil.util.addEvent(title, location: address, notes: notes, timeStr: time, eventKey: title, filterHoliday: true)
    }
    
    // MARK: other


}

extension ViewController {
   
    
}
