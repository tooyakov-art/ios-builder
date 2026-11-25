// Поле номера OneTap на настоящем iOS: симулятор iPhone, экранная клавиатура (phone pad), пальцем по клавишам.
// Только для раннера ios-builder (режим simtest): add_uitest_target.rb кладёт файл в копию проекта на машине,
// в репо приложения он не попадает. Каждый шаг пишет: что в поле после каждой клавиши, скрин, ОК/ОШИБКА.
// «Получить код» — только тестовый номер +7 700 000 19 19 и только если в поле ровно он (реальным людям коды не шлём).
import XCTest

struct SimtestError: Error, CustomStringConvertible {
  let description: String
}

final class PhoneFieldUITests: XCTestCase {
  private var app: XCUIApplication!
  private let testNumber = "7000001919"
  private var out = URL(fileURLWithPath: NSTemporaryDirectory())
  private var lines: [String] = []
  private var shotIndex = 0
  private var prefix = "t"

  override func setUp() {
    super.setUp()
    continueAfterFailure = true
    app = XCUIApplication()
    let env = ProcessInfo.processInfo.environment
    if let dir = env["SIMTEST_OUT"], !dir.isEmpty { out = URL(fileURLWithPath: dir) }
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    prefix = name.contains("test1") ? "k" : "t"
    addUIInterruptionMonitor(withDescription: "системное окно") { alert in
      for title in ["Don’t Allow", "Don't Allow", "Не разрешать", "OK", "Allow", "Разрешить"] {
        let button = alert.buttons[title]
        if button.exists { button.tap(); return true }
      }
      return false
    }
  }

  override func tearDown() {
    let text = lines.joined(separator: "\n") + "\n"
    try? text.data(using: .utf8)?.write(to: out.appendingPathComponent("result-\(prefix).txt"))
    let attachment = XCTAttachment(string: text)
    attachment.name = "result-\(prefix)"
    attachment.lifetime = .keepAlways
    add(attachment)
    super.tearDown()
  }

  /// Пальцем по клавишам экранной клавиатуры, как человек (≈3 клавиши в секунду).
  func test1_onScreenKeyboard() throws {
    let field = try openPhoneField()
    let keyboard = try onScreenKeyboard(field)
    describe(keyboard)
    describeField(field)
    shot("empty")

    tapKeys("7011234567", keyboard, field, step: "набор 7011234567")
    shot("typed-7011234567")
    expectNumber(field, "7011234567", step: "набор 7011234567")

    deleteAll(keyboard, field, step: "стирание после 7011234567")
    shot("erased")
    expectEmpty(field, step: "стирание после 7011234567")

    tapKeys("7771234567", keyboard, field, step: "набор 7771234567")
    shot("typed-7771234567")
    expectNumber(field, "7771234567", step: "набор 7771234567")

    deleteAll(keyboard, field, step: "стирание после 7771234567")
    expectEmpty(field, step: "стирание после 7771234567")

    tapKeys(testNumber, keyboard, field, step: "набор тестового номера")
    shot("typed-test-number")
    let exact = expectNumber(field, testNumber, step: "набор тестового номера")

    let submitAllowed = ProcessInfo.processInfo.environment["SIMTEST_SUBMIT"] == "true"
    if !submitAllowed {
      log("«Получить код» не нажимаю: прогон без отправки (simtest_submit=false)")
    } else if !exact {
      log("«Получить код» не нажимаю: в поле не тестовый номер — код мог бы уйти чужому")
    } else {
      submitTestNumber()
    }
  }

  /// То же, но клавишами XCUITest typeText (быстро) и системным Backspace.
  func test2_typeText() throws {
    let field = try openPhoneField()
    _ = try onScreenKeyboard(field)
    describeField(field)
    var trace: [String] = []
    for ch in "7011234567" {
      field.typeText(String(ch))
      trace.append("\(ch)→'\(settledValue(field))'")
    }
    log("typeText 7011234567: " + trace.joined(separator: " "))
    shot("typed-7011234567")
    expectNumber(field, "7011234567", step: "typeText 7011234567")

    trace = []
    for _ in 0..<16 {
      if currentValue(field).isEmpty { break }
      field.typeText(XCUIKeyboardKey.delete.rawValue)
      trace.append("⌫→'\(settledValue(field))'")
    }
    log("typeText стирание: " + trace.joined(separator: " "))
    shot("erased")
    expectEmpty(field, step: "typeText стирание")
  }

  // MARK: - шаги

  private func openPhoneField() throws -> XCUIElement {
    app.launch()
    let field = app.textFields.firstMatch
    let enter = app.buttons["Вход"]
    let deadline = Date().addingTimeInterval(240)
    var tappedEnter = false
    while Date() < deadline {
      if field.exists {
        log("экран входа по номеру открыт\(tappedEnter ? " (через «Вход»)" : "")")
        return field
      }
      if !tappedEnter, enter.exists, enter.isHittable {
        enter.tap()
        tappedEnter = true
      }
      sleep(1)
    }
    shot("no-phone-field")
    log("ОШИБКА: поле номера не появилось за 240 с")
    dumpTexts()
    throw SimtestError(description: "поле номера не появилось")
  }

  private func onScreenKeyboard(_ field: XCUIElement) throws -> XCUIElement {
    let keyboard = app.keyboards.firstMatch
    if !keyboard.waitForExistence(timeout: 8) { field.tap() }
    guard keyboard.waitForExistence(timeout: 20) else {
      shot("no-keyboard")
      log("ОШИБКА: экранной клавиатуры нет — такая проверка не настоящая")
      throw SimtestError(description: "экранной клавиатуры нет")
    }
    return keyboard
  }

  private func tapKeys(_ digits: String, _ keyboard: XCUIElement, _ field: XCUIElement, step: String) {
    var trace: [String] = []
    for ch in digits {
      let digit = String(ch)
      if let key = key(digit, in: keyboard) {
        key.tap()
      } else {
        log("нет клавиши «\(digit)» на экранной клавиатуре — typeText")
        field.typeText(digit)
      }
      usleep(300_000)
      trace.append("\(digit)→'\(settledValue(field))'")
    }
    log("\(step): " + trace.joined(separator: " "))
  }

  private func deleteAll(_ keyboard: XCUIElement, _ field: XCUIElement, step: String) {
    var trace: [String] = []
    let eraser = deleteKey(in: keyboard)
    if eraser == nil { log("нет клавиши удаления на экранной клавиатуре — typeText(delete)") }
    for _ in 0..<16 {
      if currentValue(field).isEmpty { break }
      if let eraser { eraser.tap() } else { field.typeText(XCUIKeyboardKey.delete.rawValue) }
      usleep(300_000)
      trace.append("⌫→'\(settledValue(field))'")
    }
    log("\(step): " + trace.joined(separator: " "))
  }

  private func submitTestNumber() {
    let button = app.buttons["Получить код"]
    guard button.waitForExistence(timeout: 5), button.isHittable else {
      shot("no-submit")
      log("ОШИБКА: кнопка «Получить код» не видна (закрыта клавиатурой?) — не нажимаю")
      XCTFail("кнопка «Получить код» не видна")
      return
    }
    button.tap()
    log("нажал «Получить код» (тестовый номер +7 700 000 19 19)")
    let markers = ["Код придёт в Telegram", "Код отправлен в Telegram", "Код из Telegram", "Отправили код"]
    let deadline = Date().addingTimeInterval(45)
    var found: String?
    while Date() < deadline, found == nil {
      for marker in markers where element(containing: marker).exists {
        found = marker
        break
      }
      if found == nil { sleep(1) }
    }
    shot("code-screen")
    dumpTexts()
    if let found {
      log("ОК экран кода: «\(found)»")
    } else {
      log("ОШИБКА: экран кода не открылся за 45 с")
      XCTFail("экран кода не открылся")
    }
  }

  // MARK: - поле и клавиатура

  /// Текст поля. Если XCUITest отдаёт для пустого поля подсказку (placeholderValue) — это пусто.
  private func currentValue(_ field: XCUIElement) -> String {
    guard field.exists else { return "<нет поля>" }
    let value = (field.value as? String) ?? ""
    let placeholder = field.placeholderValue ?? ""
    if !placeholder.isEmpty && value == placeholder { return "" }
    return value
  }

  private func describeField(_ field: XCUIElement) {
    let value = (field.value as? String) ?? "nil"
    log("поле до набора: value='\(value)' placeholder='\(field.placeholderValue ?? "nil")' label='\(field.label)' id='\(field.identifier)'")
  }

  /// После нажатия поле и дерево доступности Flutter обновляются за кадр-два: ждём, пока значение устоится.
  private func settledValue(_ field: XCUIElement) -> String {
    var last = currentValue(field)
    for _ in 0..<6 {
      usleep(120_000)
      let now = currentValue(field)
      if now == last { return now }
      last = now
    }
    return last
  }

  @discardableResult
  private func expectNumber(_ field: XCUIElement, _ national: String, step: String) -> Bool {
    let value = settledValue(field)
    let digits = value.filter { "0123456789".contains($0) }
    let got = (digits.count == 11 && (digits.hasPrefix("7") || digits.hasPrefix("8")))
      ? String(digits.dropFirst()) : digits
    let ok = got == national
    log("\(ok ? "ОК" : "ОШИБКА") \(step): в поле '\(value)' → номер +7\(got), ждали +7\(national)")
    if !ok { XCTFail("\(step): в поле '\(value)', ждали \(national)") }
    return ok
  }

  private func expectEmpty(_ field: XCUIElement, step: String) {
    let value = settledValue(field)
    let ok = value.isEmpty
    log("\(ok ? "ОК" : "ОШИБКА") \(step): в поле '\(value)'\(ok ? " (пусто)" : " — не стёрлось")")
    if !ok { XCTFail("\(step): осталось '\(value)'") }
  }

  private func key(_ name: String, in keyboard: XCUIElement) -> XCUIElement? {
    for query in [keyboard.keys, keyboard.buttons] {
      let element = query[name]
      if element.exists { return element }
    }
    let match = keyboard.keys.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    return match.exists ? match : nil
  }

  private func deleteKey(in keyboard: XCUIElement) -> XCUIElement? {
    for name in ["delete", "Delete", "Удалить", "удалить"] {
      for query in [keyboard.keys, keyboard.buttons] {
        let element = query[name]
        if element.exists { return element }
      }
    }
    let predicate = NSPredicate(format: "identifier CONTAINS[c] 'delete' OR label CONTAINS[c] 'delete' OR label CONTAINS[c] 'удал'")
    for query in [keyboard.keys, keyboard.buttons] {
      let match = query.matching(predicate).firstMatch
      if match.exists { return match }
    }
    return nil
  }

  private func element(containing text: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }

  // MARK: - отчёт

  private func describe(_ keyboard: XCUIElement) {
    let keys = keyboard.keys.allElementsBoundByIndex.prefix(30).map { "\($0.identifier)/\($0.label)" }
    log("клавиатура: \(keys.joined(separator: ", "))")
  }

  private func dumpTexts() {
    let texts = app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty }
    log("на экране: \(texts.joined(separator: " | "))")
  }

  private func log(_ text: String) {
    lines.append(text)
    print("SIMTEST[\(prefix)]: \(text)")
  }

  private func shot(_ name: String) {
    shotIndex += 1
    let screenshot = XCUIScreen.main.screenshot()
    let file = String(format: "%@-%02d-%@", prefix, shotIndex, name)
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = file
    attachment.lifetime = .keepAlways
    add(attachment)
    try? screenshot.pngRepresentation.write(to: out.appendingPathComponent("\(file).png"))
  }
}
