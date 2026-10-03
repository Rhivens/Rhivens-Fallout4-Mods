# Traduction française — NORA Dangerous Nights - NAF

Version correspondante : **1.1.0**

Cette traduction doit être installée **après le mod principal anglais de la même version** et gagner tous les conflits dans le gestionnaire de mods.

## Contenu du paquet distribué

```text
F4SE\Plugins\RHI_NDN_messages.ini
MCM\Config\RHI_NDN\config.json
Scripts\RHI_NDN_Controller.pex
Scripts\RHI_NDN_MCM.pex
RHI_NDN.esp
```

- `RHI_NDN.esp` traduit les dialogues et textes du plugin.
- Les deux PEX traduisent uniquement les chaînes visibles et les diagnostics. Leur structure technique reste identique aux scripts anglais.
- `config.json` traduit l’interface du MCM sans modifier les identifiants, types, valeurs minimales/maximales ni clés de réglage.
- `RHI_NDN_messages.ini` traduit les trois messages narratifs de l’intégration Pervert.

## Installation

1. Installer **NORA Dangerous Nights - NAF 1.1.0**.
2. Installer ensuite l’archive française.
3. Autoriser la traduction à remplacer les cinq fichiers correspondants.
4. Ne pas utiliser cette traduction avec une autre version du mod principal.

## Éléments publiés dans ce dossier GitHub

Le dépôt conserve les fichiers linguistiques lisibles et maintenables :

- [`MCM/config.json`](MCM/config.json)
- [`F4SE/RHI_NDN_messages.ini`](F4SE/RHI_NDN_messages.ini)

Les fichiers binaires ESP/PEX sont fournis dans l’archive française distribuée sur LoversLab. Les PSC obtenus par décompilation ne sont pas publiés comme sources, car ils ne constituent pas les sources originales de compilation.

## Contrôles effectués

- archive ZIP testée sans erreur ;
- structure technique du JSON identique à la version anglaise ;
- version MCM : `1.1.0` ;
- section `[Pervert]` et clés `BeforeStart`, `OnArrival`, `AfterReturn` conservées ;
- textes enregistrés en UTF-8 et maintenus sur une seule ligne ;
- terminologie harmonisée sur **agresseur(s)** ;
- aucun fichier temporaire ou métadonnée MO2 inclus.
