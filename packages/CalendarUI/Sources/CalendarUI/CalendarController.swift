import Cocoa
import TGUIKit
import CalendarUtils
import TelegramTheme
import GeneralRows

open class CalendarControllerView : View {
    
}

private final class CalendarNavigation : NavigationViewController {
    
    
   
}

open class CalendarController: GenericViewController<CalendarControllerView> {
    
    private var navigation:CalendarNavigation!
    private var interactions:CalendarMonthInteractions!
    private let onlyFuture: Bool
    private let lowYear: Int
    private var selectedDate: Date
    private var isActive = true
    private let limitedBy: Date?
    public var dayPreview: (Int) -> NSView? = { _ in nil }

    public func updateDayPreviews() {
        guard let controller = navigation.controller as? CalendarMonthController, controller.isLoaded() else { return }
        controller.genericView.updateDayPreviews(animated: true)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        addSubview(navigation.view)
        readyOnce()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.navigation.viewDidAppear(animated)
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let current = self?.navigation.controller as? CalendarMonthController, current.isPrevEnabled, let backAction = self?.interactions.backAction {
                backAction(current.month.month)
            }
            return .invoked
        }, with: self, for: .LeftArrow, priority: .modal)
        
        self.window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let current = self?.navigation.controller as? CalendarMonthController, current.isNextEnabled, let nextAction = self?.interactions.nextAction {
                nextAction(current.month.month)
            }
            return .invoked
        }, with: self, for: .RightArrow, priority: .modal)
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.isActive = false
        self.navigation.viewWillDisappear(animated)
        self.window?.remove(object: self, for: .LeftArrow)
        self.window?.remove(object: self, for: .RightArrow)
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigation.viewDidDisappear(animated)
    }
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.isActive = true
        self.navigation.viewWillAppear(animated)
    }
    
    public init(_ frameRect:NSRect, _ window: Window, current: Date = Date(), onlyFuture: Bool = false, limitedBy: Date? = nil, lowYear: Int = 2013, canBeNoYear: Bool = false, selectHandler:@escaping (Date)->Void, autoclose: Bool = true) {
        self.onlyFuture = onlyFuture
        self.selectedDate = current
        self.limitedBy = limitedBy
        self.lowYear = lowYear
        super.init(frame: frameRect)
        bar = .init(height: 0)
        self.interactions = CalendarMonthInteractions(lowYear: lowYear, canBeNoYear: canBeNoYear, selectAction: { [weak self] (selected) in
            guard let self, self.isActive else { return }
            self.selectedDate = selected
            if autoclose {
                self.isActive = false
                self.popover?.hide()
                self.navigationController?.modal?.close()
            }
            selectHandler(selected)
        }, backAction: { [weak self] date in
            if let strongSelf = self, strongSelf.isActive {
                strongSelf.navigation.push(strongSelf.stepMonth(date: CalendarUtils.stepMonth(-1, date: date)), style: .pop)
            }
        }, nextAction: { [weak self] date in
            if let strongSelf = self, strongSelf.isActive {
                strongSelf.navigation.push(strongSelf.stepMonth(date: CalendarUtils.stepMonth(1, date: date)), style: .push)
            }
        }, changeYear: { [weak self] year, date in
            self?.selectYear(Int(year), month: date, style: .push)
        })
        
        self.navigation = CalendarNavigation(stepMonth(date: current), window)
        self.navigation._frameRect = frameRect
        
    }
    
    open func stepMonth(date:Date, selectDayAnyway: Bool = false) -> CalendarMonthController {
        let isSelectedMonth = CalendarUtils.isSameDate(selectedDate, date: date, checkDay: false)
        return CalendarMonthController(isSelectedMonth ? selectedDate : date, onlyFuture: self.onlyFuture, limitedBy: limitedBy, selectDayAnyway: selectDayAnyway || isSelectedMonth, interactions: interactions, lowYear: self.lowYear, dayPreview: { [weak self] timestamp in
            return self?.dayPreview(timestamp)
        })
    }

    open var date: Date {
        return self.selectedDate
    }

    private func selectYear(_ year: Int, month: Date, style: ViewControllerStyle) {
        guard self.isActive else { return }
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.component(.day, from: self.selectedDate)
        let targetMonth: Date = CalendarUtils.year(year, date: month)
        var selected: Date = CalendarUtils.monthDay(min(day, CalendarUtils.lastDay(ofTheMonth: targetMonth)), date: targetMonth)
        if CalendarUtils.isYearHidden(year) {
            guard self.interactions.canBeNoYear, !self.onlyFuture else { return }
        } else {
            guard year >= self.lowYear else { return }
            let today = calendar.startOfDay(for: Date())
            var maximum = today
            if self.onlyFuture {
                guard let nextYear = calendar.date(byAdding: .year, value: 1, to: today) else { return }
                maximum = nextYear
            }
            if let limitedBy {
                maximum = min(maximum, calendar.startOfDay(for: limitedBy))
            }
            if self.onlyFuture {
                guard maximum >= today else { return }
                selected = max(selected, today)
            }
            selected = min(selected, maximum)
        }
        self.selectedDate = selected
        self.navigation.push(self.stepMonth(date: selected, selectDayAnyway: true), style: style)
    }

    open func hideYear() {
        self.selectYear(CalendarUtils.yearForNoYear, month: self.selectedDate, style: .none)
    }

    open override var isAutoclosePopover: Bool {
        return false
    }
}



