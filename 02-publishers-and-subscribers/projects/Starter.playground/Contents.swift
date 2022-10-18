import Foundation
import Combine
import _Concurrency

var subscriptions = Set<AnyCancellable>()

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

//example(of: "Future") {
//    func futureIncrement(integer: Int, afterDelay delay: TimeInterval) -> Future<Int, Never> {
//        Future<Int, Never> { promise in
//            print("Original")
//            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
//                promise(.success(integer + 1))
//            }
//        }
//    }
//
//    let future = futureIncrement(integer: 1, afterDelay: 5)
//
//    future
//        .sink(
//            receiveCompletion: { print($0) },
//            receiveValue: { print($0) }
//        )
//        .store(in: &subscriptions)
//
//    future
//        .sink(
//            receiveCompletion: { print("Second", $0) },
//            receiveValue: { print("Second", $0) }
//        )
//        .store(in: &subscriptions)
//}

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
    
    subject.send(completion: .failure(MyError.test))
    
    subject.send(completion: .finished)
    subject.send("How about another one?")
}

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

example(of: "Type erasure") {
    let subject = PassthroughSubject<Int, Never>()
    
    let publisher = subject.eraseToAnyPublisher()
    
    publisher
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
    
    subject.send(0)
}

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

/// Copyright (c) 2021 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.
