# Chapter 2: Publishers & Subscribers

## Hello Publisher
`Publisher`는 시간 경과에 따라 일련의 값을 하나 혹은  복수의 `Subscriber`에 동기・비동기로 전송할 수 있다.  
Publisher를 구독하는 것은  NotificationCenter의 notification을 구독하는 것과 유사하다.  

Publisher는 두 종류의 이벤트를 방출한다
* Element라고도 하는 Value
* Completion event

Publisher는 0개 이상의 값을 내보낼 수 있지만 하나의 completion event만 내보낼 수 있고, 
completion event를 내보내면 더 이상 이벤트를 내보낼 수 없다.  
observer를 해제하여 알림(notification)수신을 취소할 수 있다.

```swift
example(of: "Publisher") {
    // Create a notification name.
    let myNotification = Notification.Name("MyNotification")
    
    // Access NotificationCenter’s default instance, call its publisher(for:object:) method and assign its return value to a local constant.
    let publisher = NotificationCenter.default
        .publisher(for: myNotification, object: nil)
    
    // Get a handle to the default notification center.
    let center = NotificationCenter.default
    
    // Create an observer to listen for the notification with the name you previously created.
    let observer = center.addObserver(
        forName: myNotification,
        object: nil,
        queue: nil) { notification in
            print("Notification received!")
    }
    
    // Post a notification with that name.
    center.post(name: myNotification, object: nil)
    
    // Remove the observer from the notification center.
    center.removeObserver(observer)
}
```

## Hello Subscriber
`Subscriber` 는 publisher로부터 input을 받을 수 있는 타입을 선언하는 프로토콜  
`Subscriber`는 `Publisher`를 구독하여 값을 받을 수 있다. Subscriber의 `input`과 `failure`의 타입은  Publisher의 `output`과 `failure`와 일치하여야 한다.  
Publisher를 구독하기 위한 2개의 오퍼레이터: `sink(_:_:)`, `assign(to:on:)`

### Subscribing with sink(_:_:)
`unlimited demand`: sink는 publisher가 방출하는 복수의 값을 계속 받는다.  
sink는 두개의 클로저를 제공한다.
* completion event (a success or a failure)
* to handle receiving values

```swift
example(of: "Subscriber") {
    let myNotification = Notification.Name("MyNotification")
    let center = NotificationCenter.default
    
    let publisher = center.publisher(for: myNotification, object: nil)
    
    // Create a subscription by calling sink on the publisher.
    let subscription = publisher
        .sink { _ in
            print("Notification received from a publisher!")
        }
    
    // Post the notification.
    center.post(name: myNotification, object: nil)
    // Cancel the subscription.
    subscription.cancel()
}
```

`Just`는 각 subscriber에게 output을 한번만 방출한 다음 완료하는 publisher.
```swift
example(of: "Just") {
    // Create a publisher using Just, which lets you create a publisher from a single value.
    let just = Just("Hello world!")
    
    // Create a subscription to the publisher and print a message for each received event.
    _ = just
        .sink(
            receiveCompletion: {
                print("Received completion", $0)
            },
            receiveValue: {
                print("Received value", $0)
        })
    
    _ = just
        .sink(
            receiveCompletion: {
                print("Received completion (another)", $0)
            },
            receiveValue: {
                print("Received value (another)", $0)
        })
}
```

### Subscribing with assign(to:on:)
assign(to: on:)은 수신된 값을 KVO를 준수하는 오브젝트의 프로퍼티에 할당할 수 있다.
```swift
example(of: "assign(to:on:)") {
    // Define a class with a property that has a didSet property observer that prints the new value.
    class SomeObject {
        var value: String = "" {
            didSet {
                print(value)
            }
        }
    }
    
    // Create an instance of that class.
    let object = SomeObject()
    
    // Create a publisher from an array of strings.
    let publisher = ["Hello", "world!"].publisher
    
    // Subscribe to the publisher, assigning each value received to the value property of the object.
    _ = publisher
        .assign(to: \.value, on: object)
}
```

### Republishing with assign(to:)
`@Published` property wrapper를 사용하여 publisher를 구성할 수 있다  
`assign(to:)`는 내부적으로 lifecycle을 관리하고 `@Published` property가 해제(deinitialize)될 때 구독을 취소하기 때문에 `AnyCancellable` 토큰을 반환하지 않는다.

```swift
example(of: "assign(to:)") {
    // Define and create an instance of a class with a property annotated with the @Published property wrapper,
    // which creates a publisher for value in addition to being accessible as a regular property.
    class SomeObject {
        @Published var value = 0
    }
    
    let object = SomeObject()
    
    // Use the $ prefix on the @Published property to gain access to its underlying publisher,
    // subscribe to it, and print out each value received.
    object.$value
        .sink {
            print($0)
        }
    
    // Create a publisher of numbers and assign each value it emits to the value publisher of object.
    // Note the use of & to denote an inout reference to the property.
    (0..<10).publisher
        .assign(to: &object.$value)
}
```

## Hello Cancellable
작업이 끝났을 때 각 subscription을 `cancel`하면 리소스 확보와 원치 않는 side effect를 방지할 수 있다.  
subscription을 인스턴스나 컬렉션에 저장하여 deinitialization이 불려질 때 자동으로 cancel할 수 있다.  

## Understanding what’s going on
![flow](https://koenig-media.raywenderlich.com/uploads/2021/09/chapter-02-diagram-01-2-min.png)

1. subscriber가 publisher를 구독
2. publisher는 subscription을 생성해서 subscriber에게 전달
3. subscriber가 값을 요청
4. publisher가 값을 보냄
5. publisher가 완료를 보냄


```swift
public protocol Publisher {
  associatedtype Output
  associatedtype Failure : Error

  func receive<S>(subscriber: S)
    where S: Subscriber,
    Self.Failure == S.Failure,
    Self.Output == S.Input
}

extension Publisher {
  public func subscribe<S>(_ subscriber: S)
    where S : Subscriber,
    Self.Failure == S.Failure,
    Self.Output == S.Input
}
```
subscriber는 `subscribe(_:)`를 호출하여 publisher와 연결함  
`subscribe(_:)`의 구현부는 `receive(subscriber:)`를 호출하여 subscriber를 publisher에 연결함. 즉, subscription을 생성


```swift
public protocol Subscriber: CustomCombineIdentifierConvertible {
  associatedtype Input
  associatedtype Failure: Error

  func receive(subscription: Subscription)
  func receive(_ input: Self.Input) -> Subscribers.Demand
  func receive(completion: Subscribers.Completion<Self.Failure>)
}
```
publisher는 receive(subscription:)를 호출하여 subscriber에게 subscription을 보냄  
publisher는 receive(_:)를 호출하여 방금 publish된 새 값을 subscriber에게 보냄  
publisher는 receive(completion:)를 호출하여 정상적으로 or 에러로 값 생성이 종료되었음을 알려줌


```swift
public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {
  func request(_ demand: Subscribers.Demand)
}
```
Subscription은 publisher와 subscriber 사이의 connection

## Creating a custom subscriber
Subscriber는 값을 받을 때마다 `demand`를 증가시킬 수 있지만 감소시킬 수는 없다
```swift
example(of: "Custom Subscriber") {
    // Create a publisher of integers via the range’s publisher property.
    let publisher = (1...6).publisher
    
    // Define a custom subscriber, IntSubscriber.
    final class IntSubscriber: Subscriber {
        // Implement the type aliases to specify that this subscriber can receive integer inputs and will never receive errors.
        typealias Input = Int
        typealias Failure = Never
        
        /// Implement the required methods, beginning with receive(subscription:), called by the publisher
        /// and in that method, call .request(_:) on the subscription specifying
        /// that the subscriber is willing to receive up to three values upon subscription.
        func receive(subscription: Subscription) {
            print("Received subscription", subscription)
            subscription.request(.max(3))
            print("Finish the request")
        }
        
        /// Print each value as it’s received and return .none, indicating that the subscriber will not adjust its demand
        /// .none is equivalent to .max(0).
        func receive(_ input: Int) -> Subscribers.Demand {
            print("Received value", input)
//            return .none
//            return .unlimited
            return .max(1)
        }
        
        /// Print the completion event.
        func receive(completion: Subscribers.Completion<Never>) {
            print("Received completion", completion)
        }
    }
    
    let subscriber = IntSubscriber()
    
    publisher.subscribe(subscriber)
}
```

## Hello Future
`future`: 단일 값을 비동기적으로 수신하기 위한 publisher  
future는 promise를 한번만 실행(생성되자마자 실행)하는 대신에 output을 공유하거나 반복함
```swift
example(of: "Future") {
    func futureIncrement(integer: Int, afterDelay delay: TimeInterval) -> Future<Int, Never> {
        Future<Int, Never> { promise in
            print("Original")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                promise(.success(integer + 1))
            }
        }
    }

    let future = futureIncrement(integer: 1, afterDelay: 5)

    future
        .sink(
            receiveCompletion: { print($0) },
            receiveValue: { print($0) }
        )
        .store(in: &subscriptions)

    future
        .sink(
            receiveCompletion: { print("Second", $0) },
            receiveValue: { print("Second", $0) }
        )
        .store(in: &subscriptions)
}
```

## Hello Subject
`Subject`는 outside caller가 subscriber에게 (with or without a starting value.) 비동기적으로 여러 값을 보낼 수 있는 publisher이다.  
두 종류의 Subject
* PassthroughSubject
* CurrentValueSubject

### PassthroughSubject
```swift
example(of: "PassthroughSubject") {
    enum MyError: Error {
        case test
    }
    
    final class StringSubscriber: Subscriber {
        typealias Input = String
        typealias Failure = MyError
        
        func receive(subscription: Subscription) {
            subscription.request(.max(2))
        }
        
        func receive(_ input: String) -> Subscribers.Demand {
            print("Received value", input)
            return input == "World" ? .max(1) : .none
        }
        
        func receive(completion: Subscribers.Completion<MyError>) {
            print("Received completion", completion)
        }
    }
    
    let subscriber = StringSubscriber()
    
    let subject = PassthroughSubject<String, MyError>()
    subject.subscribe(subscriber)
    
    let subscription = subject
        .sink(
            receiveCompletion: { completion in
                print("Received completion (sink)", completion)
            },
            receiveValue: { value in
                print("Received value (sink)", value)
            }
        )
    
    subject.send("Hello")
    subject.send("World")
    
    subscription.cancel()
    
    subject.send("Still there?")
    
//    subject.send(completion: .failure(MyError.test))
    
    subject.send(completion: .finished)
    subject.send("How about another one?")
}
```

### CurrentValueSubject
PassthroughSubject와 다르게 현재 값에 엑세스할 수 있댜.
```swift
example(of: "CurrentValueSubject") {
    var subscriptions = Set<AnyCancellable>()
    
    let subject = CurrentValueSubject<Int, Never>(0)
    
    subject
        .print()
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
    
    subject.send(1)
    subject.send(2)
    
    print(subject.value)
    
    subject.value = 3
    print(subject.value)
    
    subject
        .print()
        .sink(receiveValue: { print("Second subscription:", $0) })
        .store(in: &subscriptions)
    
    subject.send(completion: .finished)
}
```

## Dynamically adjusting demand
```swift
example(of: "Dynamically") {
    final class IntSubscriber: Subscriber {
        typealias Input = Int
        typealias Failure = Never
        
        func receive(subscription: Subscription) {
            subscription.request(.max(2))
        }
        
        func receive(_ input: Int) -> Subscribers.Demand {
            print("Received value", input)
            
            switch input {
            case 1:
                return .max(2)
            case 3:
                return .max(1)
            default:
                return .none
            }
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            print("Received completion", completion)
        }
    }
    
    let subscriber = IntSubscriber()
    
    let subject = PassthroughSubject<Int, Never>()
    
    subject.subscribe(subscriber)
    
    subject.send(1)
    subject.send(2)
    subject.send(3)
    subject.send(4)
    subject.send(5)
    subject.send(6)
}
```

## Type erasure
`Type erasure`는　caller가 원래 타입의 세부정보에 엑세스하는 것을 방지한다.
```swift
example(of: "Type erasure") {
    let subject = PassthroughSubject<Int, Never>()
    
    let publisher = subject.eraseToAnyPublisher()
    
    publisher
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
    
    subject.send(0)
}
```

## Bridging Combine publishers to async/await
```swift
example(of: "async/await") {
    let subject = CurrentValueSubject<Int, Never>(0)
    
    Task {
        for await element in subject.values {
            print("Element: \(element)")
        }
        print("Completed")
    }
    
    subject.send(1)
    subject.send(2)
    subject.send(3)
    
    subject.send(completion: .finished)
}
```


## Key points
* `Publisher`는 시간 경과에 따라 일련의 값을 하나 혹은  복수의 `Subscriber`에 동기・비동기로 전송할 수 있다.
* `Subscriber`는 `Publisher`를 구독하여 값을 받을 수 있다. Subscriber의 `input`과 `failure`의 타입은  Publisher의 `output`과 `failure`와 일치하여야 한다.
* Publisher를 구독하기 위한 2개의 오퍼레이터: `sink(_:_:)`, `assign(to:on:)`
* Subscriber는 값을 받을 때마다 `demand`를 증가시킬 수 있지만 감소시킬 수는 없다
* 작업이 끝났을 때 각 subscription을 `cancel`하면 리소스 확보와 원치 않는 side effect를 방지할 수 있다.
* subscription을 인스턴스나 컬렉션에 저장하여 deinitialization이 불려질 때 자동으로 cancel할 수 있다.
* 단일 값을 비동기적으로 수신하기 위해 `future`를 사용한다.
* `Subject`는 outside caller가 subscriber에게 (with or without a starting value.) 비동기적으로 여러 값을 보낼 수 있는 publisher다.
* `Type erasure`는　caller가 원래 타입의 세부정보에 엑세스하는 것을 방지한다.
* `print()`　오퍼레이터를 사용하여 모든 publishing event를 콘솔에 기록할 수 있다.