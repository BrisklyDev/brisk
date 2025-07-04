// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get application => 'aplicación';

  @override
  String get language => 'Idioma';

  @override
  String get noUpdateAvailable => 'Aún no hay actualizaciones disponibles';

  @override
  String get addUrl => 'Agregar URL';

  @override
  String get download => 'Descargar';

  @override
  String get stop => 'Detener';

  @override
  String get remove => 'Eliminar';

  @override
  String get addToQueue => 'Agregar a la cola';

  @override
  String get addDownload => 'Agregar Descarga';

  @override
  String get customSavePath => 'Ruta de Guardado Personalizada';

  @override
  String get checkForUpdate => 'Buscar Actualizaciones';

  @override
  String get getExtension => 'Obtener Extensión';

  @override
  String get allDownloads => 'Todas las Descargas';

  @override
  String get unfinishedDownloads => 'Descargas Incompletas';

  @override
  String get finishedDownloads => 'Descargas Completadas';

  @override
  String get downloadQueues => 'Colas de Descargas';

  @override
  String get fileName => 'Nombre del Archivo';

  @override
  String get size => 'Tamaño';

  @override
  String get duration => 'Duración';

  @override
  String get subtitles => 'Subtítulos';

  @override
  String get progress => 'Progreso';

  @override
  String get status => 'Estado';

  @override
  String get speed => 'Velocidad';

  @override
  String get timeLeft => 'Tiempo Restante';

  @override
  String get startDate => 'Fecha de Inicio';

  @override
  String get finishDate => 'Fecha de Finalización';

  @override
  String get add_a_download_url => 'Agregar una URL de Descarga';

  @override
  String get updateDownloadUrl => 'Actualizar URL de Descarga';

  @override
  String get btn_cancel => 'Cancelar';

  @override
  String get btn_addUrl => 'Agregar URL';

  @override
  String get btn_add => 'Agregar';

  @override
  String get btn_updateUrl => 'Actualizar URL';

  @override
  String get btn_restart_extension => 'Restart Extension';

  @override
  String get err_invalidUrl_title => 'URL Inválida';

  @override
  String get err_invalidUrl_description =>
      'La URL que ingresaste parece ser inválida.\nPor favor verifica el formato e intenta de nuevo.';

  @override
  String get err_invalidUrl_descriptionHint =>
      'Asegúrate de que la URL:\n\t • Comience con https:// o http://\n\t • Contenga un nombre de dominio válido\n\t • No contenga caracteres inválidos';

  @override
  String get addNewDownload => 'Agregar Nueva Descarga';

  @override
  String get downloadInfo => 'Información de Descarga';

  @override
  String get url => 'URL';

  @override
  String get file => 'Archivo';

  @override
  String get saveAs => 'Guardar Como';

  @override
  String get pauseCapable => 'Pausable';

  @override
  String get btn_download => 'Descargar';

  @override
  String get btn_addToList => 'Agregar a la Lista';

  @override
  String get btn_openFile => 'Abrir Archivo';

  @override
  String get btn_openFileLocation => 'Abrir Ubicación del Archivo';

  @override
  String get of_ => 'de';

  @override
  String get timeRemaining => 'Tiempo Restante';

  @override
  String get activeConnections => 'Conexiones Activas';

  @override
  String get btn_showConnectionDetails => 'Mostrar Detalles de Conexión';

  @override
  String get btn_hideConnectionDetails => 'Ocultar Detalles de Conexión';

  @override
  String get connection => 'Conexión';

  @override
  String get btn_resume => 'Reanudar';

  @override
  String get btn_pause => 'Pausar';

  @override
  String get btn_wait => 'Esperar';

  @override
  String get status_paused => 'Pausado';

  @override
  String get status_downloadingFile => 'Descargando Archivo';

  @override
  String get status_connecting => 'Conectando';

  @override
  String get status_resetting => 'Reiniciando';

  @override
  String get status_complete => 'Completado';

  @override
  String get status_assemblingFile => 'Ensamblando Archivo';

  @override
  String get status_validatingFiles => 'Validando Archivos';

  @override
  String get status_downloadFailed => 'Descarga Fallida';

  @override
  String get duplicateDownload_title => 'Descarga Duplicada';

  @override
  String get duplicateDownload_description =>
      '¡Esta descarga ya existe!\nPor favor elige una acción.';

  @override
  String get btn_addNew => 'Agregar Nuevo';

  @override
  String get popupMenu_showProgress => 'Mostrar Progreso';

  @override
  String get popupMenu_properties => 'Propiedades';

  @override
  String get err_failedToRetrieveFileInfo_title =>
      'Error al obtener información del archivo';

  @override
  String get err_failedToRetrieveFileInfo_description =>
      'Algo salió mal al intentar obtener la información del archivo desde esta URL.';

  @override
  String get err_failedToRetrieveFileInfo_descriptionHint =>
      'En algunos casos, reintentar varias veces puede resolver el problema. De lo contrario, asegúrate de que el recurso al que intentas acceder sea válido.';

  @override
  String get retrievingFileInformation =>
      'Obteniendo información del archivo...';

  @override
  String get settings_title => 'Configuración';

  @override
  String get settings_menu_general => 'General';

  @override
  String get settings_menu_file => 'Archivo';

  @override
  String get settings_menu_connection => 'Conexión';

  @override
  String get settings_menu_extension => 'Extensión';

  @override
  String get settings_menu_about => 'Acerca de';

  @override
  String get settings_menu_bugReport => 'Reporte de Errores';

  @override
  String get settings_notification => 'Notificación';

  @override
  String get settings_notification_onDownloadCompletion =>
      'Notificación al completar descarga';

  @override
  String get settings_notification_onDownloadFailure =>
      'Notificación al fallar descarga';

  @override
  String get settings_userInterface => 'Interfaz de Usuario';

  @override
  String get settings_userInterface_theme => 'Tema';

  @override
  String get settings_behavior => 'Comportamiento';

  @override
  String get settings_behavior_launchAtStartup =>
      'Iniciar al arranque del sistema';

  @override
  String get settings_behavior_showProgressOnNewDownload =>
      'Mostrar ventana de progreso cuando inicie una nueva descarga';

  @override
  String get settings_behavior_appClosureBehavior =>
      'Comportamiento al Cerrar la Aplicación';

  @override
  String get settings_behavior_appClosureBehavior_alwaysAsk =>
      'Preguntar Siempre';

  @override
  String get settings_behavior_appClosureBehavior_exit => 'Salir';

  @override
  String get settings_behavior_appClosureBehavior_minimizeToTray =>
      'Minimizar a la Bandeja';

  @override
  String get settings_behavior_duplicateDownloadAction =>
      'Acción para Descarga Duplicada';

  @override
  String get settings_behavior_duplicateDownloadAction_alwaysAsk =>
      'Preguntar Siempre';

  @override
  String get settings_behavior_duplicateDownloadAction_skipDownload =>
      'Omitir Descarga';

  @override
  String get settings_behavior_duplicateDownloadAction_updateUrl =>
      'Actualizar URL';

  @override
  String get settings_behavior_duplicateDownloadAction_addNew =>
      'Agregar Nuevo';

  @override
  String get settings_logging => 'Registro de Actividad';

  @override
  String get settings_logging_enableDownloadEngineLogging =>
      'Habilitar Registro del Motor de Descarga';

  @override
  String get settings_paths => 'Rutas';

  @override
  String get settings_paths_tempFilesPath => 'Ruta de Archivos Temporales';

  @override
  String get settings_paths_savePath => 'Ruta de Guardado';

  @override
  String get settings_rules => 'Reglas';

  @override
  String get settings_rules_extensionSkipCaptureRules =>
      'Reglas de Omisión de Captura de Extensión';

  @override
  String get settings_rules_extensionSkipCaptureRules_tooltip =>
      'Define condiciones que determinan cuándo un archivo no debe capturarse a través de la extensión del navegador';

  @override
  String get settings_rules_edit => 'Editar Reglas';

  @override
  String get settings_rules_fileSavePathRules =>
      'Reglas de Ruta de Guardado de Archivos';

  @override
  String get settings_rules_fileSavePathRules_tooltip =>
      'Define condiciones que determinan cuándo un archivo debe guardarse en la ubicación especificada';

  @override
  String get settings_fileCategory => 'Categoría de Archivo';

  @override
  String get settings_fileCategory_video => 'Video';

  @override
  String get settings_fileCategory_music => 'Música';

  @override
  String get settings_fileCategory_archive => 'Archivo Comprimido';

  @override
  String get settings_fileCategory_program => 'Programa';

  @override
  String get settings_fileCategory_document => 'Documento';

  @override
  String get settings_connectionRetry => 'Reintentos de Conexión';

  @override
  String get settings_connectionRetry_maxConnectionRetryCount =>
      'Número Máximo de Reintentos de Conexión';

  @override
  String get settings_connectionRetry_connectionRetryTimeout =>
      'Tiempo de Espera para Reintentos de Conexión';

  @override
  String get infinite => 'infinito';

  @override
  String get seconds => 'Segundos';

  @override
  String get settings_proxy => 'Proxy';

  @override
  String get settings_proxy_enabled => 'Habilitado';

  @override
  String get settings_proxy_address => 'Dirección';

  @override
  String get port => 'Puerto';

  @override
  String get username => 'Nombre de Usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get settings_downloadConnections => 'Conexiones de Descarga';

  @override
  String get settings_downloadConnections_regularConnNum =>
      'Número de conexiones de descarga regulares';

  @override
  String get settings_downloadConnections_videoStreamConnNum =>
      'Número de conexiones de descarga de transmisión de video';

  @override
  String get settings_browserExtension => 'Extensión del Navegador';

  @override
  String get settings_downloadBrowserExtension =>
      'Descargar Extensión del Navegador';

  @override
  String get settings_downloadBrowserExtension_installExtension =>
      'Haz clic para instalar la extensión del navegador';

  @override
  String get settings_downloadBrowserExtension_bringWindowToFront =>
      'Traer ventana al frente en nueva descarga';

  @override
  String get changesRequireRestart => 'Los cambios requieren un reinicio';

  @override
  String get settings_info => 'Información';

  @override
  String get settings_version => 'Versión';

  @override
  String get settings_info_donate => 'Donar';

  @override
  String get settings_info_discordServer => 'Servidor de Discord';

  @override
  String get settings_info_telegramChannel => 'Canal de Telegram';

  @override
  String get settings_developer => 'Desarrollador';

  @override
  String get settings_howToBugReport => 'Cómo Reportar un Error';

  @override
  String get settings_howToBugReport_clickToOpenIssue =>
      'Haz clic para abrir un issue';

  @override
  String get settings_howToBugReport_description =>
      'Para reportar un error o solicitar una función, abre un nuevo issue en el repositorio de GitHub del proyecto y agrega las etiquetas apropiadas.';

  @override
  String get btn_saveChanges => 'Guardar Cambios';

  @override
  String get btn_resetDefaults => 'Restablecer Valores Predeterminados';

  @override
  String get btn_save => 'Guardar';

  @override
  String get type => 'Tipo';

  @override
  String get value => 'Valor';

  @override
  String get condition => 'Condición';

  @override
  String get savePath => 'Ruta de Guardado';

  @override
  String get ruleEditor_fileNameContains => 'El nombre del archivo contiene';

  @override
  String get ruleEditor_fileSizeGreaterThan =>
      'El tamaño del archivo es mayor que';

  @override
  String get ruleEditor_fileSizeLessThan =>
      'El tamaño del archivo es menor que';

  @override
  String get ruleEditor_fileExtensionIs => 'La extensión del archivo es';

  @override
  String get ruleEditor_downloadUrlContains => 'La URL de descarga contiene';

  @override
  String get err_invalidPath_title => 'Ruta Inválida';

  @override
  String get err_invalidPath_tempPath_description =>
      '¡La ruta que seleccionaste para los archivos temporales parece ser inválida!';

  @override
  String get err_invalidPath_savePath_description =>
      '¡La ruta que seleccionaste para el guardado parece ser inválida!';

  @override
  String get err_invalidPath_descriptionHint =>
      'Por favor asegúrate de que todas las carpetas en la ruta existan';

  @override
  String get error => 'Error';

  @override
  String get err_emptyValue => '¡Valor Vacío!';

  @override
  String get err_unsupportedCharacter => 'Carácter No Soportado';

  @override
  String get err_invalidSavePath => '¡Ruta de Guardado Inválida!';

  @override
  String get availableDownloads => 'Descargas Disponibles';

  @override
  String get installationGuide => 'Guía de Instalación';

  @override
  String get installBrowserExtension_title =>
      'Instalar Extensión del Navegador';

  @override
  String get installTheBrowserExtension_description =>
      'Elige tu navegador para instalar la extensión de Brisk y capturar descargas desde el navegador';

  @override
  String get installTheBrowserExtension_description_subtitle =>
      'Debido a restricciones, la extensión solo está disponible en la tienda oficial para Firefox. Para otros navegadores, se requiere instalación manual. Esperamos que esto cambie en el futuro y la extensión esté disponible para todos los navegadores en sus sitios web oficiales.';

  @override
  String get installBrowserExtensionGuide_title => 'Guía de Instalación';

  @override
  String get downloadExtension => 'Descargar Extensión';

  @override
  String get installBrowserExtension_chrome_step1_subtitle =>
      'Haz clic en el botón de abajo para descargar el paquete de extensión para Chrome';

  @override
  String get installBrowserExtension_edge_step1_subtitle =>
      'Haz clic en el botón de abajo para descargar el paquete de extensión para Edge';

  @override
  String get installBrowserExtension_opera_step1_subtitle =>
      'Haz clic en el botón de abajo para descargar el paquete de extensión para Opera';

  @override
  String get installBrowserExtension_step2_title => 'Extraer el Paquete';

  @override
  String get installBrowserExtension_step2_subtitle =>
      'Extrae el paquete descargado en el destino deseado';

  @override
  String get installBrowserExtension_step3_title =>
      'Habilitar Modo Desarrollador';

  @override
  String get installBrowserExtension_chrome_step3_subtitle =>
      'Escribe chrome://extensions en la barra de navegación y habilita el modo desarrollador junto a la barra de búsqueda';

  @override
  String get installBrowserExtension_opera_step3_subtitle =>
      'Escribe opera://extensions en la barra de navegación y habilita el modo desarrollador junto a la barra de búsqueda';

  @override
  String get installBrowserExtension_edge_step3_subtitle =>
      'Escribe edge://extensions en la barra de navegación y habilita el modo desarrollador en el menú izquierdo';

  @override
  String get installBrowserExtension_step4_title => 'Cargar Extensión';

  @override
  String get installBrowserExtension_step4_subtitle =>
      'Haz clic en el botón \'Cargar sin comprimir\' y selecciona la carpeta donde se extrajo el paquete';

  @override
  String get confirmAction => 'Confirmar Acción';

  @override
  String get downloadDeletionConfirmation =>
      '¿Estás seguro de que quieres eliminar las descargas seleccionadas?';

  @override
  String get deletionFromQueueConfirmation =>
      '¿Estás seguro de que quieres remover las descargas seleccionadas de la cola?';

  @override
  String get deleteDownloadedFiles => 'Eliminar archivos descargados';

  @override
  String get btn_deleteConfirm => 'Sí, Eliminar';

  @override
  String downloadsInQueue(Object number) {
    return '$number Descargas en cola';
  }

  @override
  String get btn_createQueue => 'Crear Cola';

  @override
  String get createNewQueue => 'Crear Nueva Cola';

  @override
  String get queueName => 'Nombre de la Cola';

  @override
  String get mainQueue => 'Cola Principal';

  @override
  String get editQueueItems => 'Editar Elementos de la Cola';

  @override
  String get queueIsEmpty => 'La cola está vacía';

  @override
  String get addDownloadToQueue => 'Agregar Descarga a la Cola';

  @override
  String get selectQueue => 'Seleccionar Cola';

  @override
  String get btn_addToQueue => 'Agregar a la Cola';

  @override
  String deleteQueueConfirmation(Object queue) {
    return '¿Estás seguro de que quieres eliminar la cola $queue?';
  }

  @override
  String get btn_schedule => 'Programar';

  @override
  String get btn_stopQueue => 'Detener Cola';

  @override
  String get scheduleDownload => 'Programar Descarga';

  @override
  String get startDownloadAt => 'Iniciar descarga a las';

  @override
  String get stopDownloadAt => 'Detener descarga a las';

  @override
  String get simultaneousDownloads => 'Descargas Simultáneas';

  @override
  String get shutdownAfterCompletion => 'Apagar después de completar';

  @override
  String get btn_startNow => 'Iniciar Ahora';

  @override
  String get chooseAction => 'Elegir Acción';

  @override
  String get appChooseActionDescription =>
      'Elige qué te gustaría hacer con la aplicación';

  @override
  String get btn_exitApplication => 'Salir de la Aplicación';

  @override
  String get btn_minimizeToTray => 'Minimizar a la Bandeja';

  @override
  String get rememberThisDecision => 'Recordar esta decisión';

  @override
  String get shutdownWarning_title => 'Advertencia de Apagado';

  @override
  String shutdownWarning_description(Object seconds) {
    return 'Tu PC se apagará en $seconds segundos';
  }

  @override
  String get btn_cancelShutdown => 'Cancelar Apagado';

  @override
  String get btn_shutdownNow => 'Apagar Ahora';

  @override
  String get extensionUpdateAvailable =>
      'Actualización de Extensión Disponible';

  @override
  String get updateAvailable => 'Actualización Disponible';

  @override
  String updateAvailable_description(Object target) {
    return 'Una nueva versión de $target está disponible.\n¿Te gustaría actualizar ahora?';
  }

  @override
  String get whatsNew => 'Qué hay de Nuevo:';

  @override
  String get btn_later => 'Más Tarde';

  @override
  String get btn_update => 'Actualizar';

  @override
  String get automaticUrlUpdate => 'Actualización Automática de URL';

  @override
  String get awaitingUrl => 'Esperando URL';

  @override
  String get awaitingUrl_description =>
      'Has sido redirigido al sitio web de referencia de este archivo.';

  @override
  String get awaitingUrl_descriptionHint =>
      'Por favor haz clic en el enlace de descarga para que la URL de descarga sea capturada y actualizada automáticamente.';

  @override
  String get urlUpdateError_title => 'Error de Actualización de URL';

  @override
  String get urlUpdateError_description =>
      '¡La URL proporcionada no se refiere al mismo archivo!';

  @override
  String get urlUpdateSuccess => '¡URL actualizada exitosamente!';

  @override
  String packageManager_updateTitle(Object target) {
    return 'Actualización de $target';
  }

  @override
  String packageManager_updateDescription(Object target) {
    return 'Brisk fue instalado vía $target y por lo tanto, la actualización automática en la aplicación está deshabilitada.';
  }

  @override
  String get packageManager_updateDescriptionHint =>
      'Por favor usa el siguiente comando para actualizar la aplicación';

  @override
  String get copiedToClipboard => 'Copiado al Portapapeles';

  @override
  String get addUrlFromClipboardHotkey =>
      'Atajo para Agregar URL desde Portapapeles';

  @override
  String get tray_showWindow => 'Mostrar Ventana';

  @override
  String get tray_exitApp => 'Salir de la Aplicación';

  @override
  String get settings_ffmpegPath => 'Ruta de FFmpeg';

  @override
  String get settings_testFFmpeg => 'Probar FFmpeg';

  @override
  String get settings_ffmpeg_tooltip =>
      'La ruta de FFmpeg debe apuntar a un directorio que contenga el binario de ffmpeg (ffmpeg.exe en Windows)\nSi ffmpeg está disponible en la ruta del sistema, establecer el valor como \'ffmpeg\' es suficiente.';

  @override
  String get settings_ffmpeg_installAutomatically =>
      'Instalar FFmpeg Automáticamente';

  @override
  String get ffmpeg_alreadyInstalled => 'FFmpeg ya está instalado';

  @override
  String get ffmpeg_notFound_title => '¡FFmpeg No Encontrado!';

  @override
  String get ffmpeg_notFound_description =>
      'Se encontraron subtítulos para esta transmisión de video, sin embargo, FFmpeg no fue encontrado en tu sistema.\nFFmpeg es requerido para agregar los subtítulos detectados al archivo de video.\n';

  @override
  String get ffmpeg_notFound_descriptionHint =>
      'Puedes:\n\t• Dejar que Brisk maneje la instalación por ti\n\t• Instalar FFmpeg vía un gestor de paquetes (choco, brew, pacman, etc.)\n\t• Descargar los binarios y agregar FFmpeg al PATH de tu sistema.\n\nSiempre puedes establecer la ruta de FFmpeg en Configuración -> General -> FFmpeg';

  @override
  String get ffmpeg_integrationSuccess => 'FFmpeg integrado exitosamente';

  @override
  String get ffmpeg_testFailed_title => '¡Prueba de FFmpeg Falló!';

  @override
  String get ffmpeg_testFailed_description =>
      '¡Falló al ejecutar comandos de FFmpeg!';

  @override
  String get ffmpeg_testFailed_descriptionHint =>
      'Asegúrate de que la ruta seleccionada contenga el binario de FFmpeg (usualmente el directorio bin)';

  @override
  String get ffmpegInstalled => 'FFmpeg fue instalado exitosamente';

  @override
  String get ffmpeg_installationNotSupported_title =>
      'Instalación Automática no soportada';

  @override
  String get ffmpeg_installationNotSupported_description =>
      'La instalación automática no es compatible con macOS.';

  @override
  String get ffmpeg_installationNotSupported_descriptionHint =>
      'Por favor instala FFmpeg usando Homebrew o cualquier otro gestor de paquetes que lo ofrezca.';

  @override
  String get btn_installLater => 'Instalaré Después';

  @override
  String get btn_installAutomatically => 'Instalar Automáticamente';

  @override
  String get settings_engine => 'Motor de Descarga';

  @override
  String get settings_engine_clientType => 'Tipo de Cliente HTTP';

  @override
  String get settings_engine_clientType_tooltip =>
      'El tipo de cliente usado para descargas:\n\nEstándar – Balanceado y estable\nRendimiento – Más rápido pero usa más CPU';

  @override
  String get settings_engine_clientType_standard => 'Estándar';

  @override
  String get settings_engine_clientType_performance => 'Rendimiento (Beta)';

  @override
  String get btn_showAdvancedOptions => 'Mostrar Opciones Avanzadas';

  @override
  String get btn_hideAdvancedOptions => 'Ocultar Opciones Avanzadas';

  @override
  String get settings_automaticFileSavePathCategorization =>
      'Categorización automática de ruta de guardado de archivos';

  @override
  String get extension_restart_success =>
      'Extension server restarted successfully!';

  @override
  String get extension_restart_failed => 'Failed to restart extension server!';
}
