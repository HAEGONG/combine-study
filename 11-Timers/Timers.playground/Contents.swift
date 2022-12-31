import UIKit
import Combine

var subscription = Set<AnyCancellable>()

example(of: "Using RunLoop") {
    let runLoop = RunLoop.main

    let sub = runLoop.schedule(
        after: runLoop.now,
        interval: .seconds(1),
        tolerance: .milliseconds(100)) {
            print("Timer fired")
        }

    runLoop.schedule(after: .init(Date(timeIntervalSinceNow: 3.0))) {
        sub.cancel()
    }
}

example(of: "Using the Timer class") {
    let publisher = Timer
        .publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .scan(0) { counter, _ in counter + 1 }
        .sink { counter in
            print("Counter is \(counter)")
        }
        .store(in: &subscription)
}

example(of: "Using DispatchQueue") {
    let queue = DispatchQueue.main
    
    let source = PassthroughSubject<Int, Never>()
    
    var counter = 0
    
    let cancellable = queue.schedule(
            after: queue.now,
            interval: .seconds(1)
        ) {
            source.send(counter)
            counter += 1
        }
        .store(in: &subscription)
    
    let subscription = source.sink {
            print("Timer emitted", $0)
        }
        .store(in: &subscription)
    
}
