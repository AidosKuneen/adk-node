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

package bls12381

import (
	"errors"
	"math/big"

	"github.com/aidoskuneen/adk-node/common"
)

func bigFromHex(hex string) *big.Int {
	return new(big.Int).SetBytes(common.FromHex(hex))
}

// decodeFieldElement expects 64 byte input with zero top 16 bytes,
// returns lower 48 bytes.
func decodeFieldElement(in []byte) ([]byte, error) {
	if len(in) != 64 {
		return nil, errors.New("invalid field element length")
	}
	// check top bytes
	for i := 0; i < 16; i++ {
		if in[i] != byte(0x00) {
			return nil, errors.New("invalid field element top bytes")
		}
	}
	out := make([]byte, 48)
	copy(out[:], in[16:])
	return out, nil
}
