#include "cw_noise.h"

#include <cmath>
#include <cstdint>

using namespace godot;

namespace zentarys {

// Les constantes du bruit, recopiees de `CWValueNoise`. Elles sont **porteuses**
// (invariant n. 1) : si elles bougent ici sans bouger la-bas, les deux moities
// du projet decrivent deux mondes.
static const uint32_t P1 = 60493u;
static const uint32_t P2 = 19990303u;
static const uint32_t P3 = 3521384707u;
static const double INV_2P30 = 9.31322574615478515625e-10; // 2^-30
static const int32_t ROW_STRIDE = 57;

// Un noeud du reseau, dans [-1, 1). Le pendant exact de `CWValueNoise.lattice`.
//
// `mul32` n'existe pas ici : le GDScript l'ecrit a la main parce que ses
// entiers sont des int64 signes et qu'il doit emuler le repli modulo 2^32. En
// `uint32_t`, le repli **est** le comportement du langage.
static inline double lattice(uint32_t n) {
	n = n ^ (n << 13);
	uint32_t m = n * n;
	m = m * P1 + P2;
	m = m * n + P3;
	return 1.0 - static_cast<double>(m & 0x7FFFFFFFu) * INV_2P30;
}

double CWNoiseNative::sample(double x, double z) const {
	const int64_t ix = static_cast<int64_t>(std::floor(x));
	const int64_t iz = static_cast<int64_t>(std::floor(z));
	const int64_t r0 = iz * ROW_STRIDE;
	const int64_t r1 = r0 + ROW_STRIDE;

	// L'interpolation cosinus, dans l'ordre exact du GDScript. `Math_PI` de
	// godot-cpp et le `PI` de GDScript sont le meme double.
	const double tx = (1.0 - std::cos((x - static_cast<double>(ix)) * Math_PI)) * 0.5;
	const double tz = (1.0 - std::cos((z - static_cast<double>(iz)) * Math_PI)) * 0.5;

	// La troncature en `uint32_t` reproduit le `& U32` du GDScript, y compris
	// pour les indices negatifs : les deux prennent les 32 bits de poids faible
	// du complement a deux.
	const double a = lattice(static_cast<uint32_t>(ix + r0));
	const double b = lattice(static_cast<uint32_t>(ix + 1 + r0));
	const double c = lattice(static_cast<uint32_t>(ix + r1));
	const double d = lattice(static_cast<uint32_t>(ix + 1 + r1));

	const double lo = a + (b - a) * tx;
	const double hi = c + (d - c) * tx;
	return lo + (hi - lo) * tz;
}

PackedFloat64Array CWNoiseNative::sample_octaves(
		const PackedFloat64Array &offsets,
		const PackedInt32Array &slots,
		const PackedFloat64Array &freqs,
		double x, double z) const {
	PackedFloat64Array out;
	const int64_t n = slots.size();
	if (freqs.size() != n) {
		return out;
	}
	out.resize(n);
	double *w = out.ptrw();
	const double *off = offsets.ptr();
	const int64_t no = offsets.size();
	for (int64_t i = 0; i < n; i++) {
		const int64_t s = slots[i];
		if (s < 0 || s + 1 >= no) {
			w[i] = 0.0;
			continue;
		}
		const double f = freqs[i];
		w[i] = sample(off[s] + x * f, off[s + 1] + z * f);
	}
	return out;
}

void CWNoiseNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("sample", "x", "z"), &CWNoiseNative::sample);
	ClassDB::bind_method(
			D_METHOD("sample_octaves", "offsets", "slots", "freqs", "x", "z"),
			&CWNoiseNative::sample_octaves);
}

} // namespace zentarys
