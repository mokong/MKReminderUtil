//
//  MKCalendarReminderUtil.swift
//  MKReminderUtil
//
//  Created by MorganWang  on 2021/5/13.
//

import UIKit
import EventKit

class MKCalendarReminderUtil: NSObject {
    
    // MARK: properties
    
    lazy fileprivate var store = EKEventStore()
    fileprivate let kCustomCalendarId = "MKCustomCalendarId"
    
    // MARK: init
    static var util: MKCalendarReminderUtil = {
         let instance = MKCalendarReminderUtil()
         return instance
     }()

    private override init() {}
    
    // MARK: utils
    // 申请日历权限
    func requestEventAuth(_ callback:((Bool) -> Void)?) {
        store.requestAccess(to: EKEntityType.event) { granted, error in
            callback?(granted)
        }
    }
    
    // 创建新的日历
    func createNewCalendar() {
        if let calendarId = MKCalendarReminderUtil.userDefaultsSaveStr(kCustomCalendarId),
              let _ = store.calendar(withIdentifier: calendarId) { // 说明本地已经创建了当前日历
            return
        }
        
        let calendar = EKCalendar(for: EKEntityType.event, eventStore: store)
        
        for item in store.sources {
            if item.title == "iCloud" || item.title == "Default" {
                calendar.source = item
                break
            }
        }
        
        calendar.title = "自定义的事项日历" // 自定义日历标题
        calendar.cgColor = UIColor.systemPurple.cgColor // 自定义日历颜色
        
        do {
            try store.saveCalendar(calendar, commit: true)
            MKCalendarReminderUtil.saveToUserDefaults(kCustomCalendarId, valueStr: calendar.calendarIdentifier)
        }
        catch {
            print(error)
        }
    }
    
    // 生成重复的规则
    func generateEKRecurrenceRule() -> EKRecurrenceRule {
        let monday = EKRecurrenceDayOfWeek(EKWeekday.monday)
        let tuesday = EKRecurrenceDayOfWeek(EKWeekday.tuesday)
        let wednesday = EKRecurrenceDayOfWeek(EKWeekday.wednesday)
        let thursday = EKRecurrenceDayOfWeek(EKWeekday.thursday)
        let friday = EKRecurrenceDayOfWeek(EKWeekday.friday)
        
        // 设置按重复频率为按周重复，重复间隔为每周都重复，一周中的周一、周二、周三、周四、周五重复
        let rule = EKRecurrenceRule(recurrenceWith: EKRecurrenceFrequency.weekly,
                                    interval: 1,
                                    daysOfTheWeek: [monday, tuesday, wednesday, thursday, friday],
                                    daysOfTheMonth: nil,
                                    monthsOfTheYear: nil,
                                    weeksOfTheYear: nil,
                                    daysOfTheYear: nil,
                                    setPositions: nil,
                                    end: nil)
        return rule
    }
    
    
    // 生成日历事件
    func generateEvent(_ title: String?, location: String?, notes: String?, timeStr: String?) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.location = location
        event.notes = notes
        
        // 事件的时间
        if let date = Date.date(from: timeStr, formatterStr: "yyyy-MM-dd HH:mm:ss") {
            // 开始
            let startDate = Date(timeInterval: 0, since: date)
            // 结束
            let endDate = Date(timeInterval: 60, since: date)
            
            // 日历提醒持续时间
            event.startDate = startDate
            event.endDate = endDate
            event.isAllDay = false
        }
        else {
            // 全天提醒
            event.isAllDay = true
        }
        
        // 添加闹钟结合（开始前多少秒）若为正则是开始后多少秒。
        let alarm = EKAlarm(relativeOffset: 0)
        event.addAlarm(alarm)
        
        if let calendarId = MKCalendarReminderUtil.userDefaultsSaveStr(kCustomCalendarId),
           let calendar = store.calendar(withIdentifier: calendarId) {
            event.calendar = calendar
        }
        
        return event
    }
    
    // 添加事件到日历
    func addEvent(_ title: String?, location: String?, notes: String?, timeStr: String, eventKey: String, filterHoliday: Bool = false) {
        requestEventAuth { [weak self] granted in
            if granted {
                // 先创建日历
                self?.createNewCalendar()
                
                // 判断事件是否存在
                if let eventId = MKCalendarReminderUtil.userDefaultsSaveStr(eventKey),
                   let _ = self?.store.event(withIdentifier: eventId) {
                    // 事件已添加
                    return
                }
                else {
                    if let event = self?.generateEvent(title, location: location, notes: notes, timeStr: timeStr),
                       let recurrenceRule = self?.generateEKRecurrenceRule() {
                        // 添加重复规则
                        event.addRecurrenceRule(recurrenceRule)

                        do {
                            try self?.store.save(event, span: EKSpan.thisEvent, commit: true)
                            //添加成功后需要保存日历关键字
                            // 保存在沙盒，避免重复添加等其他判断
                            MKCalendarReminderUtil.saveToUserDefaults(eventKey, valueStr: event.eventIdentifier)
                            
                            if filterHoliday {
                                self?.filterHolidayInfo(with: title, location: location, notes: notes, timeStr: timeStr, eventKey: eventKey)
                            }
                        }
                        catch {
                            print(error)
                        }
                    }
                }
            }
        }
    }
    
    // "多退少补"
    fileprivate func handleHolidayInfo(with days: [NSDictionary], title: String?, location: String?, notes: String?, timeStr: String, eventKey: String) {
        for dayDic in days {
            if let dayStr = dayDic["date"] as? String,
               let date = Date.date(from: dayStr, formatterStr: "yyyy-MM-dd"), // 日期
               let isOffDay = dayDic["isOffDay"] as? Bool { // 是否上班
                let interval = date.timeIntervalSince(date)
                
                // 1. 判断获取到的日期小于当前日期，说明是以前的日期，不处理
                // 2. 判断日期大于等于当前日期后，判断是否休息，判断日期那天是否有要添加的事件，
                // 3. 休息，有事件，则移除事件
                // 4. 未休息，无事件，则添加事件
                if interval < 0 {
                    continue
                }
                else {
                    if let targetEvent = eventExist(on: date, eventKey: eventKey) {
                        // 事件存在
                        if isOffDay { // 休息日
                            do {
                                try store.remove(targetEvent, span: EKSpan.thisEvent)
                            } catch {
                                print(error)
                            }
                        }
                    }
                    else {
                        // 事件不存在
                        if !isOffDay { // 非休息日，即要补班
                            var targetDateStr = dayStr
                            if let lastComponentStr = timeStr.components(separatedBy: " ").last {
                                targetDateStr = String(format: "%@ %@", dayStr, lastComponentStr)
                            }
                            
                            let event = generateEvent(title, location: location, notes: notes, timeStr: targetDateStr)
                            do {
                                try store.save(event, span: EKSpan.thisEvent)
                            } catch {
                                print(error)
                            }
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func filterHolidayInfo(with title: String?, location: String?, notes: String?, timeStr: String, eventKey: String) {
        guard let url = URL(string: "https://natescarlet.coding.net/p/github/d/holiday-cn/git/raw/master/2021.json") else {
            return
        }
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let data = data else { return }
            
            do {
                if let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary,
                   let days = jsonResult["days"] as? [NSDictionary] {
                    self?.handleHolidayInfo(with: days, title: title, location: location, notes: notes, timeStr: timeStr, eventKey: eventKey)
                }
            } catch {
                print(error)
            }
        }

        task.resume()
    }
    
    // MARK: action
    
    
    // MARK: other
    fileprivate func reminderFormatDateTimeStr(from timeStr: String, date: Date?) -> String? {
        guard let dateStr = Date.string(from: date, formatterStr: "yyyy-MM-dd") else {
            return nil
        }
        
        let dateTimeStr = String(format: "%@ %@:00", dateStr, timeStr)
        return dateTimeStr
    }
    
    // MARK: delegate
    
    
    // MARK: save && get
    
    class func userDefaultsSaveStr(_ keyStr: String) -> String? {
        return UserDefaults.standard.value(forKey: keyStr) as? String
    }
    
    class func removeFromUserDefauls(_ keyStr: String) {
        UserDefaults.standard.setValue(nil, forKey: keyStr)
        UserDefaults.standard.synchronize()
    }
    
    class func saveToUserDefaults(_ keyStr: String, valueStr: String?) {
        UserDefaults.standard.setValue(valueStr, forKey: keyStr)
        UserDefaults.standard.synchronize()
    }
    
    // 判断某天，是否有指定的事件
    fileprivate func eventExist(on tdate: Date?, eventKey: String) -> EKEvent? {
        var resultEvent: EKEvent?
        
        guard let date = tdate else {
            return resultEvent
        }
        
        let endDate = date.addingTimeInterval(TimeInterval(24 * 60 * 60))
        guard let calendarId = MKCalendarReminderUtil.userDefaultsSaveStr(kCustomCalendarId),
              let eventId = MKCalendarReminderUtil.userDefaultsSaveStr(eventKey),
              let calendar = store.calendar(withIdentifier: calendarId) else {
            return resultEvent
        }
        
        let predicate = store.predicateForEvents(withStart: date, end: endDate, calendars: [calendar])
        let events = store.events(matching: predicate)
        for event in events {
            if event.eventIdentifier == eventId {
                resultEvent = event
                break
            }
        }
        return resultEvent
    }

}
