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

// +build js

package rpc

import (
	"context"
	"errors"
	"net"
)

var errNotSupported = errors.New("rpc: not supported")

// ipcListen will create a named pipe on the given endpoint.
func ipcListen(endpoint string) (net.Listener, error) {
	return nil, errNotSupported
}

// newIPCConnection will connect to a named pipe with the given endpoint as name.
func newIPCConnection(ctx context.Context, endpoint string) (net.Conn, error) {
	return nil, errNotSupported
}
