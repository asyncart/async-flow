pub contract AsyncArtworkV2 {
    pub var count: UInt64

    pub event CounterIncremented(count: UInt64);

    pub fun increment() {
        self.count = self.count + 1 
        emit CounterIncremented(count: self.count)
    }

    init() {
        self.count = 0;
    }
}