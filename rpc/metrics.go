// Copyright 2021 The adkgo Authors
// This file is part of the adkgo library (adapted for adkgo from go--ethereum v1.10.8).
//
// the adkgo library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// the adkgo library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the adkgo library. If not, see <http://www.gnu.org/licenses/>.

package rpc

import (
	"fmt"

	"github.com/aidoskuneen/adk-node/metrics"
)

var (
	rpcRequestGauge        = metrics.NewRegisteredGauge("rpc/requests", nil)
	successfulRequestGauge = metrics.NewRegisteredGauge("rpc/success", nil)
	failedReqeustGauge     = metrics.NewRegisteredGauge("rpc/failure", nil)
	rpcServingTimer        = metrics.NewRegisteredTimer("rpc/duration/all", nil)
)

func newRPCServingTimer(method string, valid bool) metrics.Timer {
	flag := "success"
	if !valid {
		flag = "failure"
	}
	m := fmt.Sprintf("rpc/duration/%s/%s", method, flag)
	return metrics.GetOrRegisterTimer(m, nil)
}
