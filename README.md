# Mi Reforma

Aplicación local para registrar gastos de una reforma y sus tickets en macOS Apple Silicon.

El presupuesto es único para toda la reforma; las categorías solo clasifican. Los datos se guardan en la carpeta elegida por el usuario, nunca en GitHub.

## Instalador

El flujo de GitHub Actions crea `MiReforma-AppleSilicon.dmg` y lo publica en [Releases](https://github.com/admobility26/MiReforma/releases). No utiliza `upload-artifact`: el DMG no ocupa almacenamiento de artifacts de GitHub Actions. Los registros de ejecución y minutos de compilación siguen contando según el plan.

La app se firma de forma local (ad hoc), sin notarización de Apple. macOS puede pedir abrirla desde Ajustes > Privacidad y seguridad > Abrir igualmente.
