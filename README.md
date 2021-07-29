# MKReminderUtil
法定节假日日历提醒

# [iOS 工作日——过滤法定节假日日历提醒的实现](https://morganwang.cn/)

## 背景

笔者五一之前补班的时候，闹钟没响，早上差点迟到了。笔者闹钟设置的是周一到周五，iPhone没有法定节假日的设置，也没有补休的设置。。。。笔者就想要解决这个痛点，梦想着，要是做出来了，发布到商店，从此走上人生巅峰，赢取白。。。。

<!--more-->

YY过后，回过头来，接着调研，法定节假日闹钟的实现，笔者查找了很多资料，发现不用做梦了。首先iOS程序添加闹钟到时钟APP是不允许的。。。其次，iOS也没有法定节假日的判断。。。。所以不用YY了。但是笔者还真找到了[iOS自定义闹钟 —— 中国法定节假日(升级版）](https://zhuanlan.zhihu.com/p/138316230)这个，通过快捷指令自定义闹钟，可以实现过滤法定节假日。原理是：设置闹钟，然后通过快捷指令的自动执行，每天在闹钟时间前，通过订阅的别人维护的日历或者自己本地维护日历，判断当天是否是节假日，然后决定当天的闹钟是否打开、关闭。笔者不得不赞一个，真的优秀。

虽然笔者的发财梦夭折了。。。但笔者想到了另一个，虽然iOS程序不能直接添加闹钟，但是iOS程序可以直接添加日历提醒啊，比如预约直播或者预约抢购的，其实都是添加事件到日历中，然后在指定的时间，弹出来日历提醒去做什么，也不是不可以用。那是否能用日历提醒来实现，法定工作日的提醒呢。。。比如每个工作日提醒打卡。或者只针对节假日补班提醒，每个补班前天晚上提醒设置闹钟。

## 实现

iPhone 添加日历提醒的实现很简单，难的地方还是在于国内法定节假日的判断，怎么能过滤掉法定节假日，实现真正纯工作日的时候提醒？


### 第一步，先创建周一到周五的重复事件

笔者又调研了一番，发现日历提醒中有一个`EKRecurrenceRule`的规则选项，是否能用这个来实现呢？

[EKRecurrenceRule](https://developer.apple.com/documentation/eventkit/ekrecurrencerule)是什么？

官方解释：
> A class that describes the recurrence pattern for a recurring event.

笔者理解：
重复事件的重复规则。简单的说，就是定义一个重复规则，比如每周重复、每天重复、每隔几天重复类似的，然后按照这个规则添加事件。

看到这个，笔者的心凉了半截，重复的规则，对于国内法定节假日来说。。。。除了五一、国庆、元旦之外，农历的节日重复的规则找不到。。。怎么办？笔者寻思着都到这一步了，就先做个周一到周五的，也算是需求完成了半个，工作日的那部分完成了，剩下的那部分过滤法定节假日和补休，慢慢看，又不是不用😂

先来看设置每周一到周五的循环日历事件
 
**添加日历事件**
添加日历事件的步骤如下：
1. 获取读写日历权限
2. 创建单独的日历
3. 生成周一到周五的规则
4. 根据标题、地址、规则和时间生成日历事件
5. 添加事件到日历 判断生成的事件是否已经添加，已添加则不操作，没添加则添加

下面一步步来看：

1. 获取读写日历权限

    首先需要在plist中添加`Privacy - Calendars Usage Description`权限，然后使用下面代码申请权限

    ``` Swift

    lazy fileprivate var store = EKEventStore()
    
    // MARK: utils
    // 申请日历权限
    func requestEventAuth(_ callback:((Bool) -> Void)?) {
        store.requestAccess(to: EKEntityType.event) { granted, error in
            callback?(granted)
        }
    }

    ```


2. 创建单独的日历
    
    用于保证不和其它日历冲突，而且不显示或者移除时方便，建议每个自定义日历事件的都单独定义一个日历。
    
    听起来有些绕，打开iPhone，打开日历，然后点击底部中间的日历按钮，就能看到自己的所有日历。看图如下，"自定义的事项日历"即是笔者自定义的日历，笔者所添加的日历事件都会在这个日历中，如果不想要看到这些事件，可以直接把前面的勾选去除，日历中就不会显示自定义的日历事件了。或者想要删除这个日历中的所有事件时，只需要把这个日历删掉即可，不需要一条条事件删除，点击右边的提示按钮，然后滑动到最下方就有删除日历的按钮。

    Ps：默默的吐槽，不知道为啥预约抢购和预约直播提醒的，不单独建一个日历。。。。笔者预约了之后感觉烦，每次都得手动去删除事件

    <img src="https://i.loli.net/2021/05/13/S9Hgadze8hlPAYD.jpg" width="50%" height='50%'>

    创建日历的代码如下，注意calendar的source的设置，source设置为什么，最后添加的日历会显示在哪个地方

   ``` ObjectiveC

    // 创建新的日历
    func createNewCalendar() {
        guard let calendarId = MKCalendarReminderUtil.userDefaultsSaveStr(kCustomCalendarId),
              let _ = store.calendar(withIdentifier: calendarId) else { // 说明本地已经创建了当前日历
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

   ```

3. 生成周一到周五的规则
   
   使用`EKRecurrenceRule`生成每周一到周五重复的规则。`EKRecurrenceRule`的使用如下，其中`EKRecurrenceRule(recurrenceWith:interval:daysOfTheWeek:daysOfTheMonth:monthsOfTheYear:weeksOfTheYear:daysOfTheYear:setPositions:end:)`初始化方法各参数意义如下:

   - recurrenceWith: EKRecurrenceFrequency, 代表重复频率，可设置：按天、周、月、年的重复频率
   - interval: Int, 代表重复间隔，每个多久重复，不能为0
   - daysOfTheWeek: [EKRecurrenceDayOfWeek], 每周哪几天重复，设置之后，除了按天的重复频率外，都可以生效
   - daysOfTheMonth: [number], number取值1-31，也可以为负数，负数说明是从月底开始，比如-1是该月最后一天。只有在设置了按月重复频率下生效
   - monthsOfTheYear: [number], number取值1-12，只有在设置了按年重复频率下生效
   - weeksOfTheYear: [number], number取值1-53，也可以为负数，负数说明是从年底开始。只有在设置了按年重复频率下生效
   - daysOfTheYear: [number], number取值1-366，也可以为负数，负数说明是从年底开始。只有在设置了按年重复频率下生效
   - setPositions: [number], number取值1-366，也可以为负数，负值表示反向计算，过滤其它规则的过滤器，在设置了daysOfTheWeek, daysOfTheMonth, monthsOfTheYear, weeksOfTheYear, daysOfTheYear 之后有效
   - end: EKRecurrenceEnd, 重复截止日期

   ``` Swift

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

   ```

4. 根据标题、地址、备注、规则和时间生成日历事件

    生成日历事件时，要注意事件的持续时间，以及是否添加闹钟提示。这个闹钟提示不是通常意义的闹钟，是日程提醒，比如设置了事件的闹钟提示，在达到闹钟提醒时间后，会提醒响铃，且在通知栏弹出。

    ``` Swift

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

        // 添加重复规则
        let recurrenceRule = generateEKRecurrenceRule()
        event.addRecurrenceRule(recurrenceRule)

        // 添加闹钟结合（开始前多少秒）若为正则是开始后多少秒。
        let alarm = EKAlarm(relativeOffset: 0)
        event.addAlarm(alarm)
        
        if let calendarId = MKCalendarReminderUtil.userDefaultsSaveStr(kCustomCalendarId),
           let calendar = store.calendar(withIdentifier: calendarId) {
            event.calendar = calendar
        }
        
        return event
    }

    ```

5. 添加事件到日历 
    
    添加时，需要判断生成的事件是否已经添加，已添加则不操作，没添加则添加。添加成功后，把事件ID存储起来，避免重复添加同一个事件

    ``` Swift

        // 添加事件到日历
    func addEvent(_ title: String?, location: String?, notes: String?, timeStr: String, eventKey: String) {
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
                    if let event = self?.generateEvent(title, location: location, notes: notes, timeStr: timeStr) {
                        do {
                            try self?.store.save(event, span: EKSpan.thisEvent, commit: true)
                            //添加成功后需要保存日历关键字
                            // 保存在沙盒，避免重复添加等其他判断
                            MKCalendarReminderUtil.saveToUserDefaults(eventKey, valueStr: event.eventIdentifier)
                        }
                        catch {
                            print(error)
                        }
                    }
                }
            }
        }
    }

    ```

从外部使用下面代码调用

``` Swift

let date = Date.beijingDate()
let timeStr = Date.string(from: date, formatterStr: "yyyy-MM-dd HH:mm:ss")
MKCalendarReminderUtil.util.addEvent("自定义标题", location: "上海东方明珠", notes: "记得拍照打卡", timeStr: timeStr!, eventKey: "自定义标题")

```

会先弹出授权访问日历的提示框，点击允许后，成功添加到日历，然后去日历中可以看到，日历中从当天开始的，每周一至周五都有事件存在

<img src="https://i.loli.net/2021/05/14/VLlRoFKw43rXynp.png" width="50%" height="50%">

点开具体的日期，可以看到当天日期的所有事件，点击添加的事件

<img src="https://i.loli.net/2021/05/14/Fp3boaxTlgi2sJk.png" width="50%" height="50%">

可以看到事件的标题、地址、持续时间、重复频率、所属日历以及备注

<img src="https://i.loli.net/2021/05/14/DqMHQONuJGRz8yV.png" width="50%" height="50%">


至此，笔者以及成功添加了周一到周五重复提醒的事件，已经算是完成了一半，勉强能用，就是遇到节假日时，补班、调休的时候会错误提醒。所以还有后面的一般，怎么把节假日的逻辑加入到事件中？


### 第二步，添加法定节假日逻辑

笔者一直想的是添加法定节假日的逻辑，一开始其实就陷入了误区，一直想的是，是否有一个规则，按照这个规则，能自动过滤掉节假日和添加补班，然后生成重复日历事件。然而并没有这样的规则存在。

参考快捷指令节假日闹钟的实现，笔者就想到了另一种方式，如果没有直接节假日的规则，那能否分两步走？第一步先创建周一到周五的固定重复逻辑；第二步，从某个地方获取到节假日和补班信息，然后根据信息，在第一步的基础上，“多退少补”，即属于节假日的周一至周五的事件移除，属于补班的没有日历事件的则添加事件。

那这种方案是否可行呢？实践出真知！

步骤如下：

1. 获取节假日和补班信息
    从哪里能获取到节假日和补班信息呢？笔者去网上查找了一番，最终看到了有两个合适的订阅来源[holiday-cn](https://github.com/NateScarlet/holiday-cn)和[节假日 API](http://timor.tech/api/holiday)，
    - [holiday-cn](https://github.com/NateScarlet/holiday-cn)：自动每日抓取国务院公告，返回节假日和补班信息
    - [节假日 API](http://timor.tech/api/holiday)：是由私人维护的API，支持多种API接口访问，传入月份、传入日期、传入年份等等

    对于笔者来说，[holiday-cn](https://github.com/NateScarlet/holiday-cn)已满足，故而笔者选用了[holiday-cn](https://github.com/NateScarlet/holiday-cn)。当然如果公司支持，也可以在公司服务端维护一份节假日信息，能保证各端统一。甚至也可以维护在客户端一份本地json，等下一年的节假日信息出来后，再更新客户端本地的。

    返回节假日JSON格式如下，`name`是节假日名称，`date`是节假日日期，`isOffDay`代表是否是休息，比如`2021-09-18`是中秋节的补班


    ``` JSON

    {
      "$schema":"https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/schema.json",
      "$id":"https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/2021.json",
      "year":2021,
      "papers":[
          "http://www.gov.cn/zhengce/content/2020-11/25/content_5564127.htm"
      ],
      "days":[
          {
              "name":"元旦",
              "date":"2021-01-01",
              "isOffDay":true
          },
          {
              "name":"元旦",
              "date":"2021-01-02",
              "isOffDay":true
          },
          {
              "name":"元旦",
              "date":"2021-01-03",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-07",
              "isOffDay":false
          },
          {
              "name":"春节",
              "date":"2021-02-11",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-12",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-13",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-14",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-15",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-16",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-17",
              "isOffDay":true
          },
          {
              "name":"春节",
              "date":"2021-02-20",
              "isOffDay":false
          },
          {
              "name":"清明节",
              "date":"2021-04-03",
              "isOffDay":true
          },
          {
              "name":"清明节",
              "date":"2021-04-04",
              "isOffDay":true
          },
          {
              "name":"清明节",
              "date":"2021-04-05",
              "isOffDay":true
          },
          {
              "name":"劳动节",
              "date":"2021-04-25",
              "isOffDay":false
          },
          {
              "name":"劳动节",
              "date":"2021-05-01",
              "isOffDay":true
          },
          {
              "name":"劳动节",
              "date":"2021-05-02",
              "isOffDay":true
          },
          {
              "name":"劳动节",
              "date":"2021-05-03",
              "isOffDay":true
          },
          {
              "name":"劳动节",
              "date":"2021-05-04",
              "isOffDay":true
          },
          {
              "name":"劳动节",
              "date":"2021-05-05",
              "isOffDay":true
          },
          {
              "name":"劳动节",
              "date":"2021-05-08",
              "isOffDay":false
          },
          {
              "name":"端午节",
              "date":"2021-06-12",
              "isOffDay":true
          },
          {
              "name":"端午节",
              "date":"2021-06-13",
              "isOffDay":true
          },
          {
              "name":"端午节",
              "date":"2021-06-14",
              "isOffDay":true
          },
          {
              "name":"中秋节",
              "date":"2021-09-18",
              "isOffDay":false
          },
          {
              "name":"中秋节",
              "date":"2021-09-19",
              "isOffDay":true
          },
          {
              "name":"中秋节",
              "date":"2021-09-20",
              "isOffDay":true
          },
          {
              "name":"中秋节",
              "date":"2021-09-21",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-09-26",
              "isOffDay":false
          },
          {
              "name":"国庆节",
              "date":"2021-10-01",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-10-02",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-10-03",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-10-04",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-10-05",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-10-06",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-10-07",
              "isOffDay":true
          },
          {
              "name":"国庆节",
              "date":"2021-10-09",
              "isOffDay":false
          }
        ]
     }

    ```

    代码如下

    ``` Swift

    fileprivate func filterHolidayInfo(with title: String?, location: String?, notes: String?, timeStr: String, eventKey: String) {
        guard let url = URL(string: "https://natescarlet.coding.net/p/github/d/holiday-cn/git/raw/master/2021.json") else {
            return
        }
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let data = data else { return }
            
            do {
                if let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary,
                   let days = jsonResult["days"] as? [NSDictionary] {
                    // 过滤节假日
                    self?.handleHolidayInfo(with: days, title: title, location: location, notes: notes, timeStr: timeStr, eventKey: eventKey)
                }
            } catch {
                print(error)
            }
        }

        task.resume()
    }

    ```

2. “多退少补”

    即属于节假日的周一至周五的事件移除，属于补班的没有日历事件的则添加事件。这里需要判断，某天日期是否有当前的事件。

    ``` Swift

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
                            let event = generateEvent(title, location: location, notes: notes, timeStr: timeStr)
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

    ```

这个地方还有个问题需要注意，笔者在生成事件`generateEvent`的方法中，添加了重复规则，如果不修改的话，最后休息日补班调用生成事件方法时会有问题。所以这个地方要把事件重复规则的逻辑从通用的`generateEvent`方法中抽出来。放到`addEvent`方法的save之前。

最后运行调试，调用代码如下：

``` Swift

let date = Date.beijingDate()
let timeStr = Date.string(from: date, formatterStr: "yyyy-MM-dd HH:mm:ss")
MKCalendarReminderUtil.util.addEvent("自定义标题2", location: "上海东方明珠2", notes: "记得拍照打卡2", timeStr: timeStr!, eventKey: "自定义标题2", filterHoliday: true)


```

最终结果如下：

<img src="https://i.loli.net/2021/05/14/RiMj5VZrnhKqvGt.png" width="50%" height="50%">

可以看到中秋节和国庆节周一到周五的逻辑好了，之前有事件的现在已经移除了。但是应该补班的，比如9月18和9月26，事件却没有加上？什么鬼？难道是添加事件失败？调试后发现并没有，事件添加是成功的，但是日历中补班的日期却没有事件，嗯哼？

再回过头来看补班添加事件的那段代码

``` Swift 

// 事件不存在
if !isOffDay { // 非休息日，即要补班
    let event = generateEvent(title, location: location, notes: notes, timeStr: timeStr)
    do {
        try store.save(event, span: EKSpan.thisEvent)
    } catch {
        print(error)
    }
}

```

根据title、location、notes、time添加事件，噢...时间错了，这个地方应该添加的是补班的日期，而不是最开始的日期。。。所以看一下当天日期，应该能发现事件都添加到那天里面了。

所以这个地方需要修改为，从传入日期中获取时分秒，然后拼接上补班的日期，作为要设置的日期，修改如下

``` Swift

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

```

最后，调试运行，成败在此一举，哈哈哈，binggo，完美

<img src="https://i.loli.net/2021/05/14/u1P5b9eZrTNzJmy.png" width="50%" height="50%">

代码地址：[MKReminderUtil](https://github.com/mokong/MKReminderUtil)

### 总结：

![WX20210514-171744.png](https://i.loli.net/2021/05/14/mJreAbHcWNziTSD.png)

通过这种方式，生成的日历提醒，还需要考虑一点，就是节假日数据有更新的时候，如何更新？笔者这里感觉如果是在自己服务端维护一套节假日数据比较好，返回节假日数据时，也返回对应版本号。这样请求了之后，根据version对比，如果节假日数据没有更新，则无需做任何操作，如果有更新，则根据更新的数据默默的把明年的日历也创建了即可。

## 参考

- [Creating a Recurring Event](https://developer.apple.com/documentation/eventkit/ekrecurrencerule)
- [ios – 如何从日历中获取所有事件(Swift)](http://www.voidcn.com/article/p-bwvrwkpr-bwd.html)
- [holiday-cn](https://github.com/NateScarlet/holiday-cn)
- [节假日 API](http://timor.tech/api/holiday)

