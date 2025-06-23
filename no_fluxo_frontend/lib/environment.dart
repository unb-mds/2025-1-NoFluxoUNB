enum EnvironmentType {
  development,
  production,
}

class Environment {
  static String apiUrl = "http://localhost:3000";

  static EnvironmentType environmentType = EnvironmentType.development;

  static String getApiUrl() {
    return apiUrl;
  }

  static void setEnvironmentType(EnvironmentType environmentType) {
    Environment.environmentType = environmentType;

    if (environmentType == EnvironmentType.development) {
      apiUrl = "http://localhost:3000";
    } else {
      apiUrl = "https://no-fluxo.vercel.app";
    }
  }
}
