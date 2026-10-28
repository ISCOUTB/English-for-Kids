# Requisitos — English-for-Kids

> Documento de ingeniería de requerimientos del proyecto **English-for-Kids**, aplicación interactiva de aprendizaje de inglés para niños prealfabetizados.
> Versión: 0.1 (borrador) · Universidad Tecnológica de Bolívar · Proyecto de aula

---

## 1. Propósito y alcance

### 1.1 Problema
Los niños de 3 a 6 años aún no dominan la lectura ni la escritura, por lo que los métodos tradicionales de enseñanza de un segundo idioma resultan ineficaces. Se necesita un entorno digital **visual, auditivo e interactivo por voz** que les permita practicar escucha, comprensión y pronunciación con retroalimentación inmediata y adecuada a su edad.

### 1.2 Objetivo general
Desarrollar un prototipo funcional que valide el modelo de interacción central (**imagen → audio → vocalización del niño → retroalimentación positiva**) y un motor de aprendizaje adaptativo básico, dejando abierta la ampliación futura a otros idiomas y actividades.

### 1.3 Dentro del alcance (v1)
- Par de idiomas Español–Inglés.
- Vocabulario inicial de 20–30 elementos (animales, colores, números, objetos).
- Reproducción de audio, captura de voz y retroalimentación positiva sin puntajes numéricos.
- Motor de aprendizaje adaptativo básico.
- Historias para niños generadas con IA a partir de palabras estudiadas o elegidas, con narración en audio.
- Vista de progreso simplificada para padres o tutores (prioridad baja).

### 1.4 Fuera del alcance (por ahora)
- Soporte multilingüe fuera del par Español–Inglés.
- Modo totalmente offline con modelos de voz locales pesados.
- Canales de TV infantil (mejora futura, ver ADR-006).

---

## 2. Interesados (stakeholders)

| Interesado | Relación con el proyecto | Necesidades principales |
|---|---|---|
| Niño (3–6 años) | Usuario final directo | Interfaz muy visual, colorida e intuitiva; animaciones y audio; sin texto complejo ni puntajes intimidantes |
| Padre, madre, tutor o docente acompañante | Adulto responsable durante el uso | Vista simple de progreso: tiempo de uso, vocabulario visto, áreas por reforzar, sin exponer datos sensibles |
| Equipo desarrollador | Diseña, desarrolla y despliega | Arquitectura modular para iterar rápido y comparar proveedores de voz sin reescribir la app |
| Docente / evaluador | Revisor académico | Evidencia de buena ingeniería de requerimientos, arquitectura modular y gestión ágil |

---

## 3. Cómo se obtuvieron los requisitos (elicitación)

| Técnica | Resultado principal |
|---|---|
| Revisión de literatura y benchmarking (Flutter, Supabase, Azure AI Speech, OpenAI Whisper) | Flutter es viable para multiplataforma; hay que comparar Azure vs. Whisper en voz infantil |
| Talleres de ideación y prototipado (Figma) | Limitar v1 a 20–30 palabras; reemplazar puntajes por refuerzo positivo y animaciones |

---

## 4. Requisitos funcionales (RF)

Prioridad según **MoSCoW**: Must (obligatorio) · Should (importante) · Could (deseable) · Won't (no por ahora).

| ID | Nombre | Descripción | Prioridad | Criterio de aceptación |
|---|---|---|---|---|
| RF-01 | Reproducción de audio y vocabulario | El sistema reproduce la pronunciación en audio de elementos de vocabulario asociados a imágenes interactivas | Must | Al tocar la imagen, el audio suena en menos de 500 ms |
| RF-02 | Reconocimiento de voz infantil | El sistema reconoce el intento de pronunciación con el reconocedor del teléfono y lo evalúa con reglas indulgentes, con una segunda opinión de IA cuando las reglas no lo aceptan (ADR-009) | Must | Ante un intento razonable de un niño, el sistema responde "acierto" en menos de 1 segundo en la mayoría de casos; sin conexión funciona con las reglas locales |
| RF-03 | Retroalimentación positiva no numérica | Tras un intento de voz, el sistema muestra refuerzo positivo (animación o frase) en lugar de puntajes | Should | Se muestra un mensaje tipo "¡Buen trabajo!" sin porcentajes |
| RF-04 | Motor de aprendizaje adaptativo | El sistema registra aciertos y errores por concepto, estima el dominio y ajusta la frecuencia de aparición | Should | Los conceptos con menor dominio aparecen con más frecuencia |
| RF-05 | Vista de progreso para tutores | Panel simplificado con exposición al vocabulario y evolución del niño | Could | El tutor ve un resumen gráfico claro del progreso histórico |
| RF-06 | Generación de historias | El usuario selecciona palabras estudiadas o escribe otras y el sistema genera una historia corta apta para niños | Should (propuesta) | La historia usa las palabras elegidas, con lenguaje simple y sin contenido inapropiado |
| RF-07 | Narración de historias | El sistema convierte el texto de la historia en audio y lo reproduce | Should (propuesta) | La historia se puede escuchar completa desde la app |
| RF-08 | Canales de TV infantil | Sección para ver canales infantiles | Won't (mejora futura) | Fuera del alcance de la v1 (ADR-006) |
| RF-09 | Inicio de sesión del tutor | El tutor inicia sesión eligiendo su cuenta de Google, y desde ahí administra los perfiles de sus niños | Must (propuesta) | Con una cuenta de Google verificada se obtiene una sesión; con un token inválido no, y un tutor nunca ve datos de otro (ADR-008) |

---

## 5. Requisitos no funcionales (RNF)

| ID | Nombre | Descripción | Prioridad | Criterio de aceptación |
|---|---|---|---|---|
| RNF-01 | Multiplataforma | App móvil en Flutter, compatible inicialmente con Android y con posibilidad de iOS | Must | El código compila y se ejecuta en dispositivos Android |
| RNF-02 | Seguridad y privacidad | Protección de los datos de menores: cada petición verifica que el niño pertenezca al tutor de la sesión, se guardan datos mínimos y no se almacena el audio de la voz (ADR-007) | Must | Ningún usuario accede a registros de progreso ajenos |
| RNF-03 | Arquitectura modular | Separación clara entre cliente, servicios de voz, base de datos y motor de aprendizaje (monolito modular, ADR-001) | Should | Se cambia el proveedor de voz modificando solo su módulo |
| RNF-04 | Consentimiento del tutor | Antes de grabar la voz del niño o enviarla a un tercero, un adulto debe aceptar el tratamiento de datos | Must (propuesta) | El micrófono no se activa hasta que el tutor da su consentimiento |
| RNF-05 | Protección de llaves de API | Las llaves de los proveedores solo existen en el backend (ADR-003) | Must (propuesta) | El código de la app no contiene ninguna llave secreta |
| RNF-06 | Contenido seguro para niños | El texto generado por IA se restringe y se filtra antes de mostrarse | Must (propuesta) | Ninguna historia mostrada contiene contenido inapropiado en las pruebas definidas |
| RNF-07 | Vocabulario disponible sin conexión | El vocabulario base funciona sin internet (ADR-002) | Must (propuesta) | Con el dispositivo en modo avión, RF-01 sigue funcionando |
| RNF-08 | Despliegue en Docker | El backend se despliega como contenedor en panel.iscoutb.dev (ADR-005) | Should (propuesta) | El backend arranca desde la imagen Docker y responde a una petición de salud |

---

## 6. Restricciones y supuestos

> ⚠️ Sección por completar: aquí van las decisiones que **limitan** el diseño.

- **Restricción:** el backend se despliega en `panel.iscoutb.dev`, la plataforma de la universidad, empaquetado en Docker. Los requisitos de la plataforma están por confirmar.
- **Restricción:** el vocabulario base debe incluirse en la app; sus recursos deben tener licencia que permita reutilizarlos (ver ADR-002).
- **Supuesto:** los proveedores externos (Google AI Studio y ElevenLabs) estarán disponibles y su costo será asumible durante el prototipo.
- **Supuesto:** el niño usa la app acompañado por un adulto.
- **Supuesto:** el dispositivo tiene micrófono y altavoz funcionales.
- **Por definir:** conectividad requerida (¿se necesita internet para el reconocimiento de voz?).

---

## 7. Priorización (resumen MoSCoW)

| Categoría | Requisitos |
|---|---|
| **Must** (primer sprint) | RF-01, RF-02, RNF-01, RNF-02 |
| **Must** (adicionales, propuestos) | RF-09, RNF-04, RNF-05, RNF-06, RNF-07 |
| **Should** (sprints siguientes) | RF-03, RF-04, RF-06, RF-07, RNF-03, RNF-08 |
| **Could** (si hay tiempo) | RF-05, comparar proveedores de voz adicionales |
| **Won't** (por ahora) | RF-08 (TV infantil), multilingüe avanzado, modo offline pesado |

---

## 8. Cambios respecto a la idea inicial

| Elemento | Idea inicial | Hallazgo | Cambio |
|---|---|---|---|
| Actores | Solo el niño | Se necesita supervisión adulta | Se agrega el rol tutor y RF-05 |
| Evaluación | Mostrar porcentajes de precisión | Las notas numéricas frustran a niños de 3–6 años | Refuerzo positivo y animaciones (RF-03); las métricas quedan internas y en el panel de tutores |
| Reconocimiento de voz | Acoplado a un solo proveedor | Hay que comparar proveedores y validar voz infantil | Arquitectura modular (RNF-03); ElevenLabs como primera opción en lugar de Azure o Whisper (ADR-004) |
| Reconocimiento de voz (revisión) | Voz a texto remoto (ElevenLabs) en cada intento | Demasiado lento para niños de 3 a 6 años y con costo por uso | Reconocimiento en el teléfono, reglas locales y IA como segunda opinión (ADR-009) |
| Arquitectura | Microservicios | Un equipo pequeño y un solo servidor no justifican su costo | Monolito modular (ADR-001) |
| Alcance | Incluía canales de TV | Riesgos de contenido y licencias, y poco aporte al objetivo | Aplazado como mejora futura (ADR-006) |
| Despliegue | Plataforma externa | La universidad ofrece panel.iscoutb.dev | Backend en Docker en esa plataforma (ADR-005) |
| Base de datos | Supabase | La plataforma de la universidad ya incluye PostgreSQL | PostgreSQL de la plataforma (ADR-007) |
| Identificación | Solo se consideraba al niño | El adulto es quien administra la cuenta | El tutor inicia sesión con su cuenta de Google (RF-09, ADR-008) |

---

## 9. Trazabilidad (pendiente)

> Más adelante enlazaremos cada requisito con su caso de uso (`docs/diagramas/casos-de-uso.png`), con su componente en `arquitectura.md` y con sus pruebas en `tests/`.
