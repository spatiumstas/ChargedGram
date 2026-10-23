import Cocoa
import TGUIKit
import CalendarUtils
import TelegramTheme
import GeneralRows

public struct CalendarMonthInteractions {
    public let lowYear: Int
    public let canBeNoYear: Bool
    public let selectAction:(Date)->Void
    public let backAction:((Date)->Void)?
    public let nextAction:((Date)->Void)?
    public let changeYear: (Int32, Date)->Void
    public init(lowYear: Int, canBeNoYear: Bool, selectAction:@escaping (Date)->Void, backAction:((Date)->Void)? = nil, nextAction:((Date)->Void)? = nil, changeYear: @escaping(Int32, Date)->Void) {
        self.selectAction = selectAction
        self.backAction = backAction
        self.nextAction = nextAction
        self.changeYear = changeYear
        self.lowYear = lowYear
        self.canBeNoYear = canBeNoYear
    }
}

public final class CalendarMonthStruct {
    public let month:Date
    public let prevMonth:Date
    public let nextMonth:Date
    
    public let lastDayOfMonth:Int
    public let lastDayOfPrevMonth:Int
    public let lastDayOfNextMonth:Int
    
    public let currentStartDay:Int
    public var selectedDay:Int?
    
    public let components:DateComponents
    public let dayHandler:(Int)->Void
    public let onlyFuture: Bool
    public let limitedBy: Date?
    
    public let dayPreview:(Int)->NSView?
    
    public var linesCount: Int {
        switch mode {
        case .media:
            var count: Int = 0
            for i in 0 ..< 7 * 6 {
                if i + 1 < currentStartDay {
                    count += 1
                } else if (i + 2) - currentStartDay > lastDayOfMonth {
                } else {
                    count += 1
                }
            }
            let result = Int(ceil(Float(count) / 7))
            return result
        case .normal:
            return 6
        }
       
    }
    
    public enum Mode {
        case media
        case normal
    }
    public let mode: Mode
    
    public init(month:Date, mode: Mode = .normal, selectDayAnyway: Bool, onlyFuture: Bool, limitedBy: Date?, dayHandler:@escaping (Int)->Void, dayPreview:@escaping(Int)->NSView? = { _ in return nil }) {
        self.month = month
        self.onlyFuture = onlyFuture
        self.limitedBy = limitedBy
        self.dayHandler = dayHandler
        self.prevMonth = CalendarUtils.stepMonth(-1, date: month)
        self.nextMonth = CalendarUtils.stepMonth(1, date: month)
        self.lastDayOfMonth = CalendarUtils.lastDay(ofTheMonth: month)
        self.lastDayOfPrevMonth = CalendarUtils.lastDay(ofTheMonth: prevMonth)
        self.lastDayOfNextMonth = CalendarUtils.lastDay(ofTheMonth: nextMonth)
        self.mode = mode
        self.dayPreview = dayPreview
        
        
        let calendar = Calendar(identifier: .gregorian)
        
//        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: month)
        let firstDay = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))!
        self.currentStartDay = (calendar.component(.weekday, from: firstDay) + 5) % 7 + 1
        
        if selectDayAnyway {
            selectedDay = components.day!
        } else {
            selectedDay = nil
        }
        
        self.components = components
    }

    public func isDayEnabled(_ day: Int, now: Date = Date()) -> Bool {
        guard (1 ... self.lastDayOfMonth).contains(day) else { return false }
        let calendar = Calendar(identifier: .gregorian)
        let selected = calendar.startOfDay(for: CalendarUtils.monthDay(day, date: self.month))
        let today = calendar.startOfDay(for: now)
        if self.onlyFuture {
            guard let maximum = calendar.date(byAdding: .year, value: 1, to: today), selected >= today, selected <= maximum else { return false }
        } else if selected > today {
            return false
        }
        if let limitedBy = self.limitedBy, selected > calendar.startOfDay(for: limitedBy) {
            return false
        }
        return true
    }
}

open class CalendarMonthView : View {
    private var month:CalendarMonthStruct?

    private var dayPreviews: [Int : NSView] = [:]
    private let dayPreviewsViews = View()
    private let dayViews = View()
    private let containerView = View()

    /// Vertical offset reserved at the top of the view for the controller's
    /// navigation bar. The container holding day cells / previews starts at
    /// this y so that bar chrome doesn't overlap the calendar grid.
    open var navigationBarHeight: CGFloat = 64 {
        didSet {
            if navigationBarHeight != oldValue {
                needsLayout = true
            }
        }
    }

    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.addSubview(dayPreviewsViews)
        containerView.addSubview(dayViews)

        backgroundColor = .clear
    }
    
    open override func scrollWheel(with event: NSEvent) {
        if let month = month {
            switch month.mode {
            case .media:
                super.scrollWheel(with: event)
            default:
                break
            }
        }
    }
    
    open func layout(for month:CalendarMonthStruct) {
        dayPreviewsViews.removeAllSubviews()
        dayViews.removeAllSubviews()
        if self.month?.month != month.month {
            self.dayPreviews.removeAll()
        }
        self.month = month

        for i in 0 ..< 7 * 6 {
            let day = TextButton()
            day.set(font: .normal(.text), for: .Normal)
            day.scaleOnClick = true
            let hideExcess: Bool
            switch month.mode {
            case .media:
                hideExcess = true
            case .normal:
                hideExcess = false
            }
            let current:Int
            
            if i + 1 < month.currentStartDay {
                current = (month.lastDayOfPrevMonth - month.currentStartDay) + i + 2
                day.set(color: theme.colors.grayText, for: .Normal)
                day.isHidden = hideExcess
            } else if (i + 2) - month.currentStartDay > month.lastDayOfMonth {
                current = (i + 2) - (month.currentStartDay + month.lastDayOfMonth)
                day.set(color: theme.colors.grayText, for: .Normal)
                day.isHidden = hideExcess
            } else {
                current = (i + 1) - month.currentStartDay + 1
                
                let skipDay = !month.isDayEnabled(current)
                let dayTimeinterval = CalendarUtils.monthDay(current, date: month.month).timeIntervalSince1970
                
                let dayPreview = self.dayPreviews[current] ?? month.dayPreview(Int(dayTimeinterval))
                if let dayPreview = dayPreview {
                    self.dayPreviews[current] = dayPreview
                    self.dayPreviewsViews.addSubview(dayPreview)
                }
                day.contextObject = current
                
                if !skipDay {
                    day.set(color: theme.colors.underSelectedColor, for: .Highlight)
                    if (i + 1) % 7 == 0 || (i + 2) % 7 == 0 {
                        day.set(color: theme.colors.redUI, for: .Normal)
                    } else {
                        day.set(color: theme.colors.text, for: .Normal)
                    }
                    if dayPreview != nil {
                        day.set(background: .clear, for: .Normal)
                        day.set(background: .clear, for: .Highlight)
                        day.set(color: .white, for: .Normal)
                        day.set(font: .medium(.text), for: .Normal)
                    } else {
                        switch month.mode {
                        case .media:
                            day.set(background: .clear, for: .Normal)
                            day.set(background: theme.colors.background, for: .Highlight)
                            day.set(color: theme.colors.text, for: .Highlight)
                        case .normal:
                            if let selectedDay = month.selectedDay, current == selectedDay {
                               // day.isSelected = true
                                day.set(color: theme.colors.underSelectedColor, for: .Normal)
                                
                                day.set(background: theme.colors.accent, for: .Normal)
                                day.set(background: theme.colors.accent, for: .Highlight)
                            } else {
                                day.set(background: .clear, for: .Normal)
                                day.set(background: theme.colors.accent, for: .Highlight)
                            }
                        }
                        
                    }
                   
                    day.set(handler: { [weak self] (control) in
                        if month.mode != .media {
                            month.selectedDay = current
                        }
                        month.dayHandler(current)
                        self?.layout(for: month)
                        
                    }, for: .Click)
                } else {
                    day.set(color: theme.colors.grayText, for: .Normal)
                }
            }
            day.set(text: "\(current)", for: .Normal)
            
            dayViews.addSubview(day)
        }
        
        self.needsLayout = true
    }
    
    public func updateDayPreviews(animated: Bool) {
        guard let month else { return }
        layoutSubtreeIfNeeded()
        let animated = animated && window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for case let day as TextButton in dayViews.subviews {
            guard let current = day.contextObject as? Int, month.isDayEnabled(current), dayPreviews[current] == nil else { continue }
            let timestamp = Int(CalendarUtils.monthDay(current, date: month.month).timeIntervalSince1970)
            guard let preview = month.dayPreview(timestamp) else { continue }
            let previous: View?
            if animated, let bitmap = day.bitmapImageRepForCachingDisplay(in: day.bounds) {
                day.cacheDisplay(in: day.bounds, to: bitmap)
                let snapshot = View(frame: day.frame)
                snapshot.isEventLess = true
                snapshot.layer?.contents = bitmap.cgImage
                dayViews.addSubview(snapshot)
                previous = snapshot
            } else {
                previous = nil
            }
            dayPreviews[current] = preview
            dayPreviewsViews.addSubview(preview)
            preview.setFrameOrigin(day.frame.midX - preview.frame.width / 2, day.frame.midY - preview.frame.height / 2)
            day.set(background: .clear, for: .Normal)
            day.set(background: .clear, for: .Highlight)
            day.set(color: .white, for: .Normal)
            day.set(font: .medium(.text), for: .Normal)
            day.layoutSubtreeIfNeeded()
            if animated {
                preview.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                day.layer?.animateAlpha(from: 0, to: 1, duration: 0.16)
                previous?.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] _ in
                    previous?.removeFromSuperview()
                })
            }
        }
    }

    open override func layout() {
        super.layout()

        containerView.frame = NSMakeRect(0, navigationBarHeight - 10, frame.width, max(0, frame.height - (navigationBarHeight - 10)))
        dayViews.frame = containerView.bounds
        dayPreviewsViews.frame = containerView.bounds

        guard let month = self.month else {
            return
        }

        let containerSize = containerView.frame.size

        let oneSize:NSSize
        var inset:NSPoint
        switch month.mode {
        case .normal:
            oneSize = NSMakeSize(floorToScreenPixels(backingScaleFactor, (containerSize.width - 20) / 7), floorToScreenPixels(backingScaleFactor, (containerSize.height - 20) / CGFloat(month.linesCount)))
            inset = NSMakePoint(10, 10)
        case .media:
            oneSize = NSMakeSize(floorToScreenPixels(backingScaleFactor, (containerSize.width - 20) / 7), floorToScreenPixels(backingScaleFactor, containerSize.height / CGFloat(month.linesCount)))
            inset = NSMakePoint(10, 0)
        }

        for i in 0 ..< dayViews.subviews.count {
            if let view = dayViews.subviews[i] as? TextButton {
                view.frame = NSMakeRect(inset.x, inset.y, oneSize.width, oneSize.height)
                view.layer?.cornerRadius = view.frame.height / 2
                if let currentDay = view.contextObject as? Int {
                    if let preview = self.dayPreviews[currentDay] {
                        preview.setFrameOrigin(inset.x + (view.frame.width - preview.frame.width) / 2, inset.y + (view.frame.height - preview.frame.height) / 2)
                    }
                }
                inset.x += oneSize.width
                if (i + 1) % 7 == 0 {
                    inset.x = 10
                    inset.y += oneSize.height
                }
            }
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}



open class CalendarMonthController: GenericViewController<CalendarMonthView> {
    public let interactions:CalendarMonthInteractions
    public let month:CalendarMonthStruct
    public let onlyFuture: Bool
    public let limitedBy: Date?
    public let lowYear: Int
    public let date: Date
    public init(_ month:Date, onlyFuture: Bool, limitedBy: Date?, selectDayAnyway: Bool, interactions:CalendarMonthInteractions, lowYear: Int = 2013, dayPreview: @escaping (Int) -> NSView? = { _ in nil }) {
        self.onlyFuture = onlyFuture
        self.limitedBy = limitedBy
        self.lowYear = lowYear
        self.date = month
        self.month = CalendarMonthStruct(month: month, selectDayAnyway: selectDayAnyway, onlyFuture: self.onlyFuture, limitedBy: self.limitedBy, dayHandler: { day in
            interactions.selectAction(CalendarUtils.monthDay(day, date: month))
        }, dayPreview: dayPreview)
        self.interactions = interactions
        
        super.init()
        self.bar = NavigationBarStyle(height: 64)
    }
    
    open override func getCenterBarViewOnce() -> TitledBarView {
        let formatter:DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: appAppearance.language.languageCode)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "LLLL"
        let monthString:String = formatter.string(from: month.month)
        formatter.dateFormat = "yyyy"
        let yearString:String
        if CalendarUtils.isYearHidden(month.components.year!) {
            yearString = "—"
        } else {
            yearString = formatter.string(from: month.month)
        }
        
        let barView = TitledBarView(controller: self, .initialize(string: monthString, color: theme.colors.text, font:.medium(.text)), .initialize(string:yearString, color: theme.colors.grayText, font:.normal(.small)))
        barView.removeAllHandlers()
        
        let lowYear = self.interactions.lowYear
        let canBeNoYear = self.interactions.canBeNoYear

        barView.contextMenu = { [weak self] in
            guard let `self` = self else {
                return nil
            }
            
            let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            
            var now: time_t = time_t(nowTimestamp)
            var timeinfoNow: tm = tm()
            localtime_r(&now, &timeinfoNow)
            
             var items:[ContextMenuItem] = []
            
            if canBeNoYear {
                items.append(.init("—", handler: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.interactions.changeYear(Int32(CalendarUtils.yearForNoYear), self.month.month)
                }))
            }
            
            for i in stride(from: 1900 + timeinfoNow.tm_year, to: Int32(lowYear) - 1, by: -1) {
                items.append(.init("\(i)", handler: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.interactions.changeYear(i, self.month.month)
                }))
            }
            if !items.isEmpty && !self.onlyFuture {
                let menu = ContextMenu(betterInside: true)
                for item in items {
                    menu.addItem(item)
                }
                return menu
            }
            return nil
        }
        
        
        return barView
    }
    
    open var isNextEnabled:Bool {
        let monthStart: Date = CalendarUtils.monthDay(1, date: month.month)
        let currentMonth: Date = CalendarUtils.monthDay(1, date: Date())
        if self.onlyFuture {
            let calendar = Calendar(identifier: .gregorian)
            guard let maximum = calendar.date(byAdding: .year, value: 1, to: currentMonth) else { return false }
            return monthStart < maximum
        }
        if CalendarUtils.isYearHidden(month.components.year!) {
            return month.components.month! < 12
        }
        return monthStart < currentMonth
    }

    open var isPrevEnabled:Bool {
        if self.onlyFuture {
            let monthStart: Date = CalendarUtils.monthDay(1, date: month.month)
            let currentMonth: Date = CalendarUtils.monthDay(1, date: Date())
            return monthStart > currentMonth
        }
        return month.components.year! > lowYear || ((month.components.year == lowYear || CalendarUtils.isYearHidden(month.components.year!)) && month.components.month! > 1)
    }
    
    open override func getLeftBarViewOnce() -> BarView {
        let bar = ImageBarView(controller: self, theme.icons.calendarBack)
        bar.button.isEnabled = isPrevEnabled
        
        if isPrevEnabled {
            bar.button.set(handler: { [weak self] (control) in
                if let backAction = self?.interactions.backAction, let month = self?.month.month {
                    backAction(month)
                }
            }, for: .Click)
        }
        
        bar.set(image: bar.button.isEnabled ? theme.icons.calendarBack : theme.icons.calendarBackDisabled)
        return bar
    }
    
    open override func getRightBarViewOnce() -> BarView {
        let bar = ImageBarView(controller: self, theme.icons.calendarNext)
        bar.button.isEnabled = isNextEnabled

        if isNextEnabled {
            bar.button.set(handler: { [weak self] (control) in
                if let nextAction = self?.interactions.nextAction, let month = self?.month.month {
                    nextAction(month)
                }
            }, for: .Click)
        }
       
        bar.set(image: bar.button.isEnabled ? theme.icons.calendarNext : theme.icons.calendarNextDisabled)
        return bar
    }
    
    open override var removeAfterDisapper: Bool {
        return true
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.layout(for: month)
        
        readyOnce()
    }

    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    
}

