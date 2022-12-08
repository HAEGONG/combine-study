import UIKit
import Combine

struct Sample: Decodable {
    let id: Int
    let title: String
    let price: Int
}

var subscriptions = Set<AnyCancellable>()

example(of: "dataTaskPublisher") {
    guard let url = URL(string: "https://dummyjson.com/products/1") else {
        return
    }

    let sub = URLSession.shared
        .dataTaskPublisher(for: url)
        .sink(receiveCompletion: { completion in
            if case .failure(let err) = completion {
                print("Retrieving data failed with error", err)
            }
        }, receiveValue: { data, response in
            print("Retrieved data of size \(data.count), response = \(response)")
        })
        .store(in: &subscriptions)
}

example(of: "decode") {
    guard let url = URL(string: "https://dummyjson.com/products/1") else {
        return
    }

    let sub = URLSession.shared
        .dataTaskPublisher(for: url)
//        .tryMap { data, _ in
//            try JSONDecoder().decode(Sample.self, from: data)
//        }
        .map(\.data)
        .decode(type: Sample.self, decoder: JSONDecoder())
        .sink(receiveCompletion: { completion in
            if case .failure(let err) = completion {
                print("Retrieving data failed with error", err)
            }
        }, receiveValue: { object in
            print("Retrieved data", object)
        })
        .store(in: &subscriptions)
}

example(of: "multicast") {
    guard let url = URL(string: "https://dummyjson.com/products/1") else {
        return
    }
    
    let publisher = URLSession.shared
        .dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: Sample.self, decoder: JSONDecoder())
        .multicast { PassthroughSubject<Sample, Error>() }
    
    let sub1 = publisher
        .sink(receiveCompletion: { completion in
            if case .failure(let err) = completion {
                print("Sink1 Retrieving data failed with error", err)
            }
        }, receiveValue: { object in
            print("Sink1 Retrieved data", object)
        })
        .store(in: &subscriptions)
    
    let sub2 = publisher
        .sink(receiveCompletion: { completion in
            if case .failure(let err) = completion {
                print("Sink2 Retrieving data failed with error", err)
            }
        }, receiveValue: { object in
            print("Sink2 Retrieved data", object)
        })
        .store(in: &subscriptions)
    
    let sub = publisher
        .connect()
        .store(in: &subscriptions)
}
