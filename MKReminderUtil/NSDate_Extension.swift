//
//  NSDate_Extension.swift
//  MKReminderUtil
//
//  Created by MorganWang  on 2021/5/14.
//

import Foundation

extension Date {
    
    static func beijingDate() -> Date? {
        var date = Date()
        let zone = TimeZone(identifier: "Asia/Shanghai")
        if let interval = zone?.secondsFromGMT(for: date) {
            date = date.addingTimeInterval(TimeInterval(interval))
        }
        return date
    }
    
    static func string(from tdate: Date?, formatterStr: String) -> String? {
        guard let date = tdate else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = formatterStr
        
        let zone = TimeZone(identifier: "Asia/Shanghai")
        dateFormatter.timeZone = zone

        let dateStr = dateFormatter.string(from: date)
        return dateStr
    }
        
    static func date(from tdateStr: String?, formatterStr: String) -> Date? {
        guard let dateStr = tdateStr else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = formatterStr
        
        let zone = TimeZone(identifier: "Asia/Shanghai")
        dateFormatter.timeZone = zone
        
        if var rdate = dateFormatter.date(from: dateStr) {
//           let interval = zone?.secondsFromGMT(for: rdate) {
//            rdate = rdate.addingTimeInterval(TimeInterval(interval))
            return rdate
        }
        else {
            return nil
        }
    }
}
