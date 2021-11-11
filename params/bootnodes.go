// Copyright 2021 The adkgo Authors
// This file is part of the adkgo library.
//
// The adkgo library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The adkgo library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the adkgo library. If not, see <http://www.gnu.org/licenses/>.

package params

import "github.com/aidoskuneen/adk-node/common"

// MainnetBootnodes are the enode URLs of the P2P bootstrap nodes running on
// the main adkgo Ref Ethereum network.
var MainnetBootnodes = []string{
}

// RopstenBootnodes are the enode URLs of the P2P bootstrap nodes running on the
// Ropsten test network.
var RopstenBootnodes = []string{
}

// RinkebyBootnodes are the enode URLs of the P2P bootstrap nodes running on the
// Rinkeby test network.
var RinkebyBootnodes = []string{
}

// GoerliBootnodes are the enode URLs of the P2P bootstrap nodes running on the
// Görli test network.
var GoerliBootnodes = []string{
}

var V5Bootnodes = []string{
}

//const dnsPrefix = "enrtree://AKA3AM6LPBYEUDMVNU3BSVQJ5AD45Y7YPOHJLEF6W26QOE4VTUDPE@"

// KnownDNSNetwork returns the address of a public DNS-based node list for the given
// genesis hash and protocol. See https://github.com/aidoskuneen/discv4-dns-lists for more
// information.
func KnownDNSNetwork(genesis common.Hash, protocol string) string {
	// var net string
	// switch genesis {
	// case MainnetGenesisHash:
	// 	net = "mainnet"
	// case RopstenGenesisHash:
	// 	net = "ropsten"
	// case RinkebyGenesisHash:
	// 	net = "rinkeby"
	// case GoerliGenesisHash:
	// 	net = "goerli"
	// default:
		return ""
	//}
	//return dnsPrefix + protocol + "." + net + ".ethdisco.net"
}
