# 🤖 Yocto Build System — Jetson Nano + Ollama LLM

Contenedor Docker con todas las herramientas para construir una imagen Linux
embebida usando **Yocto Project** para la tarjeta **NVIDIA Jetson Nano**, con
soporte para ejecutar modelos LLM localmente via **Ollama**.

---

## 📐 Arquitectura del Stack

```
┌─────────────────────────────────────────────────────────┐
│               Docker Build Container                      │
│               (Ubuntu 22.04 x86_64)                      │
│                                                           │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │    Poky    │  │ meta-tegra   │  │  meta-ollama     │ │
│  │ (Yocto     │  │ (Jetson Nano │  │  (receta custom) │ │
│  │  base)     │  │  L4T, CUDA)  │  │                  │ │
│  └────────────┘  └──────────────┘  └──────────────────┘ │
│                                                           │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │ meta-oe    │  │  meta-clang  │  │ meta-virtualiz.  │ │
│  │ (recetas   │  │  (LLVM para  │  │                  │ │
│  │  extendid) │  │  llama.cpp)  │  │                  │ │
│  └────────────┘  └──────────────┘  └──────────────────┘ │
│                                                           │
│              BitBake Build System                         │
└───────────────────────┬─────────────────────────────────┘
                        │ Cross-compile (aarch64)
                        ▼
┌─────────────────────────────────────────────────────────┐
│              Imagen Generada (tegraflash/ext4)            │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │         Linux aarch64 (Yocto Kirkstone)              │ │
│  │                                                       │ │
│  │  systemd  →  ollama.service                          │ │
│  │               ├── llama.cpp (CUDA backend)            │ │
│  │               └── Maxwell GPU (128 cores, CC 5.3)    │ │
│  │                                                       │ │
│  │  API REST: http://jetson-llm:11434                   │ │
│  │  Modelos recomendados:                               │ │
│  │    - phi3:mini  (3.8B, ~2.3GB) ← recomendado        │ │
│  │    - llama3.2:1b (1B, ~0.8GB) ← rápido              │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
│         NVIDIA Jetson Nano (tegra210)                     │
│         Cortex-A57 × 4 @ 1.43GHz                         │
│         4GB LPDDR4 (shared CPU/GPU)                       │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 Requisitos del Host de Build

| Recurso      | Mínimo    | Recomendado  |
|--------------|-----------|--------------|
| CPU          | 4 cores   | 16+ cores    |
| RAM          | 16 GB     | 32 GB        |
| Disco libre  | 150 GB    | 250+ GB      |
| Docker       | 24.x+     | latest       |
| SO           | Linux/macOS/Windows (WSL2) |

> ⚠️ **Tiempo de build**: El primer build completo puede tomar **6-12 horas**.
> Con sstate-cache (segunda vez): ~30 minutos.

---

## 🚀 Inicio Rápido

### 1. Clonar este repositorio

```bash
git clone https://github.com/tu-usuario/yocto-jetson-ollama
cd yocto-jetson-ollama
```

### 2. Construir el contenedor Docker

```bash
docker-compose build
# o: docker build -t yocto-jetson-ollama:kirkstone .
```

### 3. Iniciar el contenedor

```bash
docker-compose up -d
docker-compose exec builder bash
```

### 4. Configurar y clonar capas de Yocto (dentro del contenedor)

```bash
/yocto/scripts/setup-yocto.sh
```

### 5. Iniciar el build

```bash
# Opción A: Script directo
/yocto/scripts/build-image.sh

# Opción B: Manual
source /yocto/layers/poky/oe-init-build-env /yocto/build
bitbake jetson-nano-llm-image

# Opción C: Usando kas (reproducible)
kas build /yocto/conf-templates/kas-jetson-nano.yml
```

---

## 📦 Capas Yocto Incluidas

| Capa                    | Versión/Branch              | Propósito                           |
|-------------------------|-----------------------------|-------------------------------------|
| `poky`                  | `kirkstone`                 | Base de Yocto Project               |
| `meta-openembedded`     | `kirkstone`                 | Recetas extendidas (Python, net...) |
| `meta-tegra`            | `kirkstone-l4t-r35.x`       | Soporte Jetson Nano / CUDA          |
| `meta-clang`            | `kirkstone`                 | LLVM/Clang (compilar llama.cpp)     |
| `meta-virtualization`   | `kirkstone`                 | Contenedores en target              |
| `meta-ollama`           | local                       | Receta custom Ollama LLM            |

---

## 🤖 Modelos LLM Recomendados para Jetson Nano

La Jetson Nano tiene **4GB de RAM compartida** entre CPU y GPU. Los modelos
cuantizados en formato GGUF son los más eficientes:

| Modelo          | Tamaño  | RAM Req. | Velocidad | Notas                    |
|-----------------|---------|----------|-----------|--------------------------|
| `phi3:mini`     | ~2.3 GB | ~3.0 GB  | ~5 tok/s  | ✅ **Recomendado**        |
| `llama3.2:1b`   | ~0.8 GB | ~1.5 GB  | ~12 tok/s | Rápido, menos preciso    |
| `tinyllama`     | ~0.6 GB | ~1.2 GB  | ~15 tok/s | Ultra liviano            |
| `llama3.2:3b`   | ~2.0 GB | ~3.5 GB  | ~4 tok/s  | Buena calidad            |
| `mistral:7b-q4` | ~4.1 GB | ~5+ GB   | ❌ OOM    | Demasiado grande         |

> ⚠️ Modelos de 7B+ generalmente causan OOM en la Jetson Nano 4GB.

---

## 📡 Uso de Ollama en la Jetson Nano

Una vez flasheada y arrancada la imagen:

```bash
# Estado del servicio
systemctl status ollama

# Descargar modelos (requiere internet)
ollama-pull-models     # script incluido en la imagen

# Chat interactivo
ollama run phi3:mini

# API REST
curl http://localhost:11434/api/generate \
  -d '{"model":"phi3:mini","prompt":"Explica qué es IoT","stream":false}'

# Listar modelos disponibles
ollama list
```

---

## 📁 Estructura del Proyecto

```
yocto-jetson-ollama/
├── Dockerfile                     # Contenedor de build
├── docker-compose.yml             # Orquestación con volúmenes
├── docker-entrypoint.sh           # Script de entrada
│
├── scripts/
│   ├── setup-yocto.sh             # Clonar capas y configurar
│   └── build-image.sh             # Iniciar build
│
├── conf/
│   ├── local.conf                 # Config principal Yocto
│   ├── bblayers.conf              # Capas activas
│   └── kas-jetson-nano.yml        # Build reproducible con kas
│
├── meta-ollama/                   # Capa Yocto custom
│   ├── conf/
│   │   └── layer.conf
│   ├── recipes-ai/
│   │   └── ollama/
│   │       ├── ollama_0.1.32.bb   # Receta de Ollama
│   │       └── files/
│   │           ├── ollama.service  # Servicio systemd
│   │           └── ollama-environment
│   └── recipes-images/
│       └── jetson-nano-llm-image.bb  # Imagen completa
│
└── output/                        # Imágenes generadas (gitignored)
```

---

## ⚡ Consejos de Optimización de Build

```bash
# Usar todos los cores disponibles
export BB_NUMBER_THREADS=$(nproc)
export PARALLEL_MAKE="-j$(nproc)"

# Habilitar hash equivalence server (acelera sstate)
echo 'BB_HASHSERVE = "auto"' >> /yocto/build/conf/local.conf

# Build en RAM (si tienes >64GB RAM en el host)
# mount -t tmpfs -o size=60g tmpfs /yocto/build/tmp

# Ver progreso en tiempo real
bitbake jetson-nano-llm-image 2>&1 | tee build.log
```

---

## 🔍 Troubleshooting

**Error: `do_fetch` falla en recetas de NVIDIA/CUDA**
```bash
# Aceptar licencias manualmente
echo 'LICENSE_FLAGS_ACCEPTED += "nvidia-tegra commercial"' \
  >> /yocto/build/conf/local.conf
```

**Error: Espacio en disco insuficiente**
```bash
# Limpiar sstate-cache antiguo
bitbake -c cleansstate world
# o eliminar tmp/
rm -rf /yocto/build/tmp
```

**Ollama falla al arrancar en Jetson Nano (OOM)**
```bash
# Editar /etc/ollama/environment y reducir:
OLLAMA_GPU_MEMORY_FRACTION=0.70
OLLAMA_NUM_GPU=16    # Menos capas en GPU
```

---

## 📄 Licencias

- Yocto Project: MIT
- meta-tegra: MIT + NVIDIA Tegra License
- Ollama: MIT
- CUDA Runtime: NVIDIA CUDA EULA

> La imagen generada incluye componentes bajo la licencia NVIDIA Tegra.
> Revisar los términos antes de distribución comercial.
