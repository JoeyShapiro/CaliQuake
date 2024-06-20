import Foundation

print("Hello, World!")
setup()
print("Setup done")

sleep(1000)

print("Goodbye, World!")

func setup() {
    signal(SIGTERM) {s in
        print("sig term \(s)")
    }
    signal(SIGINT) {s in
        print("sigint \(s)")
    }
}
