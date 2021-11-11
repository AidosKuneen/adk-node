package main

type ResponseError struct {
    Error string    `json:"error"`
    Duration int64    `json:"duration"`
}

type ResponsePing struct {
    IP string       `json:"ip"`
    Duration int64    `json:"duration"`
}

type ResponseFindTransactions struct {//{"hashes":["ABC","DEF9"],"duration":0}
    Hashes []string       `json:"hashes"`
    Duration int64    `json:"duration"`
}

type ResponseGetBalances struct {//{"hashes":["ABC","DEF9"],"duration":0}
    Balances []string       `json:"balances"`
    Milestone string       `json:"milestone"`
    MilestoneIndex int       `json:"milestoneIndex"`
    Duration int64    `json:"duration"`
}

type ResponseGetInclusionStates struct {//{"hashes":["ABC","DEF9"],"duration":0}
    States []bool       `json:"states"`
    Duration int64    `json:"duration"`
}

type ResponseGetNodeInfo struct {
    AppName string `json:"appName"` //":"ARI",
    AppVersion string `json:"appVersion"` //":"1.0.3.0",
    JreAvailableProcessors int `json:"jreAvailableProcessors"` //":16,
    JreFreeMemory int64 `json:"jreFreeMemory"` //":6495493312,
    JreVersion string `json:"jreVersion"` //":"1.8.0_292",
    JreMaxMemory int64 `json:"jreMaxMemory"` //":15011938304,
    JreTotalMemory int64 `json:"jreTotalMemory"` //":8241283072,
    LatestMilestone string `json:"latestMilestone"` //":"TZQWBHPRSGPLMCFZYWZZLERRVETLDCNAWPGILZZOUWJJKFZZPEEDMGYLPLRSTBKRPNXVIAYQVZA999999",
    LatestMilestoneIndex int64 `json:"latestMilestoneIndex"` //":746443,
    LatestSolidSubmeshMilestone string `json:"latestSolidSubmeshMilestone"` //":"TZQWBHPRSGPLMCFZYWZZLERRVETLDCNAWPGILZZOUWJJKFZZPEEDMGYLPLRSTBKRPNXVIAYQVZA999999",
    LatestSolidSubmeshMilestoneIndex int64 `json:"latestSolidSubmeshMilestoneIndex"` //":746443,
    Peers int64 `json:"peers"` //":4,
    PacketsQueueSize int64 `json:"packetsQueueSize"` //":0,
    Time int64 `json:"time"` //":1630494905600,
    Tips int `json:"tips"` //":104,
    TransactionsToRequest int `json:"transactionsToRequest"` //":0,
    Duration int64    `json:"duration"`
}

type ResponseGetTips struct {
    Hashes []string       `json:"hashes"`
    Duration int64    `json:"duration"`
}

type ResponseGetTransactionsToApprove struct {
    TrunkTransaction string       `json:"trunkTransaction"`
    BranchTransaction string       `json:"branchTransaction"`
    Duration int64    `json:"duration"`
}

type ResponseGetTrytes struct {
    Trytes []string       `json:"trytes"`
    Duration int64    `json:"duration"`
}

type ResponseDurationOnly struct {
    Duration int64    `json:"duration"`
}

type ResponseAddPeer struct {
    AddedPeer int    `json:"addedPeer"`
    Duration int64    `json:"duration"`
}

type ResponseGetPeerAddresses struct {
    Peerlist []string    `json:"peerlist"`
    Duration int64    `json:"duration"`
}
