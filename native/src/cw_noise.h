// Le bruit de valeur de Zentarys, en natif.
//
// -- Ce que ce fichier doit etre, avant d'etre rapide --------------------------
//
// Il doit rendre **exactement les memes bits** que `src/worldgen/cw_value_noise.gd`.
// L'invariant n. 1 du depot dit pourquoi : les constantes de ce bruit fixent
// l'identite de tous les mondes deja engendres, et une derive d'un ulp les
// change tous. Ce n'est pas une preference, c'est le contrat.
//
// Trois consequences sur la facon d'ecrire ce fichier :
//
//   * **l'arithmetique entiere est en `uint32_t`**, ou le debordement est
//     defini et vaut exactement le masquage `& 0xFFFFFFFF` que le GDScript
//     emule a la main. `mul32` disparait donc : `a * b` sur des `uint32_t`
//     *est* `mul32` ;
//   * **pas de contraction FMA, pas de reciproque approchee.** MSVC ne contracte
//     pas sous `/fp:precise`, qui est le defaut, et le SConstruct le pose
//     explicitement plutot que de compter dessus ;
//   * **l'ordre des operations est celui du GDScript**, jusqu'aux parentheses.
//     `lo + (hi - lo) * tz` n'est pas `lo * (1 - tz) + hi * tz`.
//
// La verification n'est pas dans ce fichier : c'est `_test_value_noise` de
// `tests/worldgen_test.gd`, qui compare a des references calculees
// independamment, et une verification d'accord bit a bit ajoutee le
// 2026-09-11 qui compare les deux implementations sur des milliers de points.

#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

namespace zentarys {

class CWNoiseNative : public godot::Object {
	GDCLASS(CWNoiseNative, godot::Object)

protected:
	static void _bind_methods();

public:
	// Un echantillon. Le remplacant direct de `CWValueNoise.sample`.
	double sample(double x, double z) const;

	// N octaves en **un seul passage de frontiere**.
	//
	// C'est la raison d'etre de cette extension autant que la vitesse du calcul
	// lui-meme : un appel de methode depuis GDScript coute une fraction de
	// microseconde, et `_height_from` en fait quinze par colonne. Les rendre en
	// un appel est ce qui transforme un gain de calcul en gain de chargement.
	//
	// `offsets` porte les decalages de graine par paires (x, z) — c'est le
	// rangement de `CWWorldParams.noise_offsets`, garde tel quel pour qu'aucune
	// conversion ne s'intercale.
	godot::PackedFloat64Array sample_octaves(
			const godot::PackedFloat64Array &offsets,
			const godot::PackedInt32Array &slots,
			const godot::PackedFloat64Array &freqs,
			double x, double z) const;
};

} // namespace zentarys
