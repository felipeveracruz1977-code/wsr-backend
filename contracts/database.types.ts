export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      achievements: {
        Row: {
          description: string
          icon_url: string
          id: string
          key: string
          name: string
          required_sessions: number | null
          required_streak: number | null
        }
        Insert: {
          description: string
          icon_url?: string
          id?: string
          key: string
          name: string
          required_sessions?: number | null
          required_streak?: number | null
        }
        Update: {
          description?: string
          icon_url?: string
          id?: string
          key?: string
          name?: string
          required_sessions?: number | null
          required_streak?: number | null
        }
        Relationships: []
      }
      activities: {
        Row: {
          avg_pace_s_per_km: number | null
          created_at: string
          distance_m: number
          duration_s: number
          ended_at: string
          feeling: Database["public"]["Enums"]["activity_feeling"] | null
          id: string
          is_shared: boolean
          notes: string | null
          route_polyline: string | null
          route_storage_path: string | null
          started_at: string
          title: string
          user_id: string
          visibility: string
        }
        Insert: {
          avg_pace_s_per_km?: number | null
          created_at?: string
          distance_m: number
          duration_s: number
          ended_at: string
          feeling?: Database["public"]["Enums"]["activity_feeling"] | null
          id?: string
          is_shared?: boolean
          notes?: string | null
          route_polyline?: string | null
          route_storage_path?: string | null
          started_at: string
          title?: string
          user_id: string
          visibility?: string
        }
        Update: {
          avg_pace_s_per_km?: number | null
          created_at?: string
          distance_m?: number
          duration_s?: number
          ended_at?: string
          feeling?: Database["public"]["Enums"]["activity_feeling"] | null
          id?: string
          is_shared?: boolean
          notes?: string | null
          route_polyline?: string | null
          route_storage_path?: string | null
          started_at?: string
          title?: string
          user_id?: string
          visibility?: string
        }
        Relationships: []
      }
      adherence_scores: {
        Row: {
          calculated_at: string
          checkins_analyzed: number | null
          component_a: number
          component_b: number
          component_c: number
          created_at: string
          dias_sin_checkin: number | null
          dias_sin_sesion: number | null
          id: string
          nivel: string
          runner_id: string
          score: number
          scored_date: string
          sessions_analyzed: number | null
          triggered_by: string
        }
        Insert: {
          calculated_at?: string
          checkins_analyzed?: number | null
          component_a?: number
          component_b?: number
          component_c?: number
          created_at?: string
          dias_sin_checkin?: number | null
          dias_sin_sesion?: number | null
          id?: string
          nivel: string
          runner_id: string
          score: number
          scored_date?: string
          sessions_analyzed?: number | null
          triggered_by?: string
        }
        Update: {
          calculated_at?: string
          checkins_analyzed?: number | null
          component_a?: number
          component_b?: number
          component_c?: number
          created_at?: string
          dias_sin_checkin?: number | null
          dias_sin_sesion?: number | null
          id?: string
          nivel?: string
          runner_id?: string
          score?: number
          scored_date?: string
          sessions_analyzed?: number | null
          triggered_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "adherence_scores_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_request_log: {
        Row: {
          id: number
          requested_at: string
          user_id: string
        }
        Insert: {
          id?: number
          requested_at?: string
          user_id: string
        }
        Update: {
          id?: number
          requested_at?: string
          user_id?: string
        }
        Relationships: []
      }
      alerts: {
        Row: {
          created_at: string
          id: string
          payload: Json
          resolved: boolean
          severity: string
          source: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          payload?: Json
          resolved?: boolean
          severity: string
          source: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          payload?: Json
          resolved?: boolean
          severity?: string
          source?: string
          user_id?: string
        }
        Relationships: []
      }
      ambassador_agreements: {
        Row: {
          created_at: string
          distancia_carrera: string
          domicilio_embajadora: string
          email_embajadora: string
          estado: string
          fecha_aceptacion: string | null
          fecha_dia: number | null
          fecha_envio_email: string | null
          fecha_mes: string | null
          fechas_proceso: string
          id: string
          ip_aceptacion: string | null
          nombre_carrera: string
          nombre_embajadora: string
          rut_embajadora: string
          sponsor_event_id: string | null
          token: string
        }
        Insert: {
          created_at?: string
          distancia_carrera: string
          domicilio_embajadora: string
          email_embajadora: string
          estado?: string
          fecha_aceptacion?: string | null
          fecha_dia?: number | null
          fecha_envio_email?: string | null
          fecha_mes?: string | null
          fechas_proceso: string
          id?: string
          ip_aceptacion?: string | null
          nombre_carrera: string
          nombre_embajadora: string
          rut_embajadora: string
          sponsor_event_id?: string | null
          token?: string
        }
        Update: {
          created_at?: string
          distancia_carrera?: string
          domicilio_embajadora?: string
          email_embajadora?: string
          estado?: string
          fecha_aceptacion?: string | null
          fecha_dia?: number | null
          fecha_envio_email?: string | null
          fecha_mes?: string | null
          fechas_proceso?: string
          id?: string
          ip_aceptacion?: string | null
          nombre_carrera?: string
          nombre_embajadora?: string
          rut_embajadora?: string
          sponsor_event_id?: string | null
          token?: string
        }
        Relationships: [
          {
            foreignKeyName: "ambassador_agreements_sponsor_event_id_fkey"
            columns: ["sponsor_event_id"]
            isOneToOne: false
            referencedRelation: "sponsor_events"
            referencedColumns: ["id"]
          },
        ]
      }
      anamnesis: {
        Row: {
          autoriza_datos: boolean
          calidad_sueno: number | null
          capacidad_lograr_objetivos: number | null
          carga_familiar: number | null
          carga_laboral: number | null
          ciclo_regular: string | null
          cigarrillos_por_dia: string | null
          ciudad: string | null
          clinica_afiliada: string | null
          comidas_por_dia: string | null
          condiciones_previas: string[]
          condiciones_previas_otra: string | null
          consent_ai_at: string | null
          consent_health_at: string | null
          consent_retention_at: string | null
          created_at: string
          cuales_sintomas: string | null
          deporte_actividad: string | null
          descripcion_alimentacion: string | null
          descripcion_lesion: string | null
          descripcion_operacion: string | null
          dia_preferido_largo: string | null
          diabetes: boolean
          dias_entrenamiento: string[] | null
          dias_puede_entrenar: number | null
          dias_semana_corre: number | null
          distancia_carrera: string | null
          dolor_actual: number | null
          donde_dolor: string | null
          edad: number
          edad_hijos: string | null
          emergencia_contacto: string | null
          emergencia_nombre: string | null
          entrenamiento_fuerza: string | null
          estado_civil: string | null
          etapa_vital: string | null
          exito_en_wsr: string | null
          expectativa_comunidad: string | null
          fecha_carrera: string | null
          fecha_lesion: string | null
          fecha_nacimiento: string | null
          fuma_cigarrillos: boolean
          ha_corrido: boolean | null
          ha_seguido_planes: boolean | null
          ha_trabajado_con_coach: boolean | null
          hipercolesterolemia: boolean
          hipertension: boolean
          historial_familiar: boolean
          historial_familiar_detalle: string | null
          horas_sueno: string | null
          id: string
          isapre_afiliada: string | null
          km_por_semana: string | null
          latidos_anormales: boolean
          latidos_anormales_cuando: string | null
          lesion_genera_molestias: boolean | null
          lesiones_24_meses: boolean | null
          lesiones_articulares: boolean
          lesiones_articulares_detalle: string | null
          lesiones_musculares: boolean
          lesiones_musculares_detalle: string | null
          lesiones_oseas: boolean
          lesiones_oseas_detalle: string | null
          medicamentos_detalle: string | null
          medico_restringio_ejercicio: boolean | null
          motivaciones: string | null
          motivo_entrar_wsr: string | null
          movilidad_elongacion: boolean | null
          nivel_estres: number | null
          nivel_runner: string | null
          nombre_apellido: string
          nombre_carrera: string | null
          nombre_rut_firma: string
          num_hijos: number | null
          objetivo_12_meses: string | null
          objetivo_principal: string | null
          operada_5_anos: boolean | null
          otros_deportes: string | null
          pais: string | null
          patologias_diagnostico: string | null
          patologias_fecha_tratamiento: string | null
          patologias_medicas: boolean
          pierde_motivacion: string | null
          preferencia_acompanamiento: string | null
          preocupaciones_running: string | null
          presion_arterial: string | null
          presion_arterial_desconoce: boolean
          profesion: string | null
          que_valoras: string[] | null
          realiza_actividad_fisica: boolean
          red_flags: string[] | null
          reflexion_final: string | null
          region: string | null
          resistencia_insulina: boolean
          ritmo_10k: string | null
          ritmo_21k: string | null
          runner_email: string | null
          runner_id: string | null
          seguridad_corriendo: number | null
          semana_dificil_respuesta: string | null
          sintomas_afectan_entrenamientos: boolean | null
          suplementos: string[]
          suplementos_otro_detalle: string | null
          telefono: string | null
          temperatura_entrenamiento: string | null
          tiempo_corriendo: string | null
          tiempo_para_ti: number | null
          tiempo_por_sesion: string | null
          tiene_carrera_objetivo: boolean | null
          tiene_hijos: boolean | null
          tipo_terreno: string | null
          token_id: string | null
          toma_alcohol: boolean
          toma_medicamentos: boolean
          ultimo_examen_sangre: string | null
          updated_at: string
          usa_anticonceptivos_hormonales: boolean | null
        }
        Insert: {
          autoriza_datos?: boolean
          calidad_sueno?: number | null
          capacidad_lograr_objetivos?: number | null
          carga_familiar?: number | null
          carga_laboral?: number | null
          ciclo_regular?: string | null
          cigarrillos_por_dia?: string | null
          ciudad?: string | null
          clinica_afiliada?: string | null
          comidas_por_dia?: string | null
          condiciones_previas?: string[]
          condiciones_previas_otra?: string | null
          consent_ai_at?: string | null
          consent_health_at?: string | null
          consent_retention_at?: string | null
          created_at?: string
          cuales_sintomas?: string | null
          deporte_actividad?: string | null
          descripcion_alimentacion?: string | null
          descripcion_lesion?: string | null
          descripcion_operacion?: string | null
          dia_preferido_largo?: string | null
          diabetes?: boolean
          dias_entrenamiento?: string[] | null
          dias_puede_entrenar?: number | null
          dias_semana_corre?: number | null
          distancia_carrera?: string | null
          dolor_actual?: number | null
          donde_dolor?: string | null
          edad?: number
          edad_hijos?: string | null
          emergencia_contacto?: string | null
          emergencia_nombre?: string | null
          entrenamiento_fuerza?: string | null
          estado_civil?: string | null
          etapa_vital?: string | null
          exito_en_wsr?: string | null
          expectativa_comunidad?: string | null
          fecha_carrera?: string | null
          fecha_lesion?: string | null
          fecha_nacimiento?: string | null
          fuma_cigarrillos?: boolean
          ha_corrido?: boolean | null
          ha_seguido_planes?: boolean | null
          ha_trabajado_con_coach?: boolean | null
          hipercolesterolemia?: boolean
          hipertension?: boolean
          historial_familiar?: boolean
          historial_familiar_detalle?: string | null
          horas_sueno?: string | null
          id?: string
          isapre_afiliada?: string | null
          km_por_semana?: string | null
          latidos_anormales?: boolean
          latidos_anormales_cuando?: string | null
          lesion_genera_molestias?: boolean | null
          lesiones_24_meses?: boolean | null
          lesiones_articulares?: boolean
          lesiones_articulares_detalle?: string | null
          lesiones_musculares?: boolean
          lesiones_musculares_detalle?: string | null
          lesiones_oseas?: boolean
          lesiones_oseas_detalle?: string | null
          medicamentos_detalle?: string | null
          medico_restringio_ejercicio?: boolean | null
          motivaciones?: string | null
          motivo_entrar_wsr?: string | null
          movilidad_elongacion?: boolean | null
          nivel_estres?: number | null
          nivel_runner?: string | null
          nombre_apellido: string
          nombre_carrera?: string | null
          nombre_rut_firma?: string
          num_hijos?: number | null
          objetivo_12_meses?: string | null
          objetivo_principal?: string | null
          operada_5_anos?: boolean | null
          otros_deportes?: string | null
          pais?: string | null
          patologias_diagnostico?: string | null
          patologias_fecha_tratamiento?: string | null
          patologias_medicas?: boolean
          pierde_motivacion?: string | null
          preferencia_acompanamiento?: string | null
          preocupaciones_running?: string | null
          presion_arterial?: string | null
          presion_arterial_desconoce?: boolean
          profesion?: string | null
          que_valoras?: string[] | null
          realiza_actividad_fisica?: boolean
          red_flags?: string[] | null
          reflexion_final?: string | null
          region?: string | null
          resistencia_insulina?: boolean
          ritmo_10k?: string | null
          ritmo_21k?: string | null
          runner_email?: string | null
          runner_id?: string | null
          seguridad_corriendo?: number | null
          semana_dificil_respuesta?: string | null
          sintomas_afectan_entrenamientos?: boolean | null
          suplementos?: string[]
          suplementos_otro_detalle?: string | null
          telefono?: string | null
          temperatura_entrenamiento?: string | null
          tiempo_corriendo?: string | null
          tiempo_para_ti?: number | null
          tiempo_por_sesion?: string | null
          tiene_carrera_objetivo?: boolean | null
          tiene_hijos?: boolean | null
          tipo_terreno?: string | null
          token_id?: string | null
          toma_alcohol?: boolean
          toma_medicamentos?: boolean
          ultimo_examen_sangre?: string | null
          updated_at?: string
          usa_anticonceptivos_hormonales?: boolean | null
        }
        Update: {
          autoriza_datos?: boolean
          calidad_sueno?: number | null
          capacidad_lograr_objetivos?: number | null
          carga_familiar?: number | null
          carga_laboral?: number | null
          ciclo_regular?: string | null
          cigarrillos_por_dia?: string | null
          ciudad?: string | null
          clinica_afiliada?: string | null
          comidas_por_dia?: string | null
          condiciones_previas?: string[]
          condiciones_previas_otra?: string | null
          consent_ai_at?: string | null
          consent_health_at?: string | null
          consent_retention_at?: string | null
          created_at?: string
          cuales_sintomas?: string | null
          deporte_actividad?: string | null
          descripcion_alimentacion?: string | null
          descripcion_lesion?: string | null
          descripcion_operacion?: string | null
          dia_preferido_largo?: string | null
          diabetes?: boolean
          dias_entrenamiento?: string[] | null
          dias_puede_entrenar?: number | null
          dias_semana_corre?: number | null
          distancia_carrera?: string | null
          dolor_actual?: number | null
          donde_dolor?: string | null
          edad?: number
          edad_hijos?: string | null
          emergencia_contacto?: string | null
          emergencia_nombre?: string | null
          entrenamiento_fuerza?: string | null
          estado_civil?: string | null
          etapa_vital?: string | null
          exito_en_wsr?: string | null
          expectativa_comunidad?: string | null
          fecha_carrera?: string | null
          fecha_lesion?: string | null
          fecha_nacimiento?: string | null
          fuma_cigarrillos?: boolean
          ha_corrido?: boolean | null
          ha_seguido_planes?: boolean | null
          ha_trabajado_con_coach?: boolean | null
          hipercolesterolemia?: boolean
          hipertension?: boolean
          historial_familiar?: boolean
          historial_familiar_detalle?: string | null
          horas_sueno?: string | null
          id?: string
          isapre_afiliada?: string | null
          km_por_semana?: string | null
          latidos_anormales?: boolean
          latidos_anormales_cuando?: string | null
          lesion_genera_molestias?: boolean | null
          lesiones_24_meses?: boolean | null
          lesiones_articulares?: boolean
          lesiones_articulares_detalle?: string | null
          lesiones_musculares?: boolean
          lesiones_musculares_detalle?: string | null
          lesiones_oseas?: boolean
          lesiones_oseas_detalle?: string | null
          medicamentos_detalle?: string | null
          medico_restringio_ejercicio?: boolean | null
          motivaciones?: string | null
          motivo_entrar_wsr?: string | null
          movilidad_elongacion?: boolean | null
          nivel_estres?: number | null
          nivel_runner?: string | null
          nombre_apellido?: string
          nombre_carrera?: string | null
          nombre_rut_firma?: string
          num_hijos?: number | null
          objetivo_12_meses?: string | null
          objetivo_principal?: string | null
          operada_5_anos?: boolean | null
          otros_deportes?: string | null
          pais?: string | null
          patologias_diagnostico?: string | null
          patologias_fecha_tratamiento?: string | null
          patologias_medicas?: boolean
          pierde_motivacion?: string | null
          preferencia_acompanamiento?: string | null
          preocupaciones_running?: string | null
          presion_arterial?: string | null
          presion_arterial_desconoce?: boolean
          profesion?: string | null
          que_valoras?: string[] | null
          realiza_actividad_fisica?: boolean
          red_flags?: string[] | null
          reflexion_final?: string | null
          region?: string | null
          resistencia_insulina?: boolean
          ritmo_10k?: string | null
          ritmo_21k?: string | null
          runner_email?: string | null
          runner_id?: string | null
          seguridad_corriendo?: number | null
          semana_dificil_respuesta?: string | null
          sintomas_afectan_entrenamientos?: boolean | null
          suplementos?: string[]
          suplementos_otro_detalle?: string | null
          telefono?: string | null
          temperatura_entrenamiento?: string | null
          tiempo_corriendo?: string | null
          tiempo_para_ti?: number | null
          tiempo_por_sesion?: string | null
          tiene_carrera_objetivo?: boolean | null
          tiene_hijos?: boolean | null
          tipo_terreno?: string | null
          token_id?: string | null
          toma_alcohol?: boolean
          toma_medicamentos?: boolean
          ultimo_examen_sangre?: string | null
          updated_at?: string
          usa_anticonceptivos_hormonales?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "anamnesis_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "anamnesis_token_id_fkey"
            columns: ["token_id"]
            isOneToOne: false
            referencedRelation: "anamnesis_tokens"
            referencedColumns: ["id"]
          },
        ]
      }
      anamnesis_tokens: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          runner_email: string
          runner_nombre: string | null
          token: string
          used_at: string | null
        }
        Insert: {
          created_at?: string
          expires_at?: string
          id?: string
          runner_email: string
          runner_nombre?: string | null
          token?: string
          used_at?: string | null
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          runner_email?: string
          runner_nombre?: string | null
          token?: string
          used_at?: string | null
        }
        Relationships: []
      }
      assessments: {
        Row: {
          anaerobic_threshold_hr: number | null
          assessment_date: string
          assessment_type: string
          coach_id: string | null
          created_at: string
          endurance_score: number | null
          height_cm: number | null
          id: string
          lactate_threshold_pace: string | null
          max_hr_estimated: number | null
          mobility_score: number | null
          observations: string | null
          overall_score: number | null
          pace_10k: string | null
          pace_21k: string | null
          pace_5k: string | null
          resting_hr: number | null
          runner_id: string
          strength_score: number | null
          updated_at: string
          vo2max_estimate: number | null
          weight_kg: number | null
        }
        Insert: {
          anaerobic_threshold_hr?: number | null
          assessment_date?: string
          assessment_type?: string
          coach_id?: string | null
          created_at?: string
          endurance_score?: number | null
          height_cm?: number | null
          id?: string
          lactate_threshold_pace?: string | null
          max_hr_estimated?: number | null
          mobility_score?: number | null
          observations?: string | null
          overall_score?: number | null
          pace_10k?: string | null
          pace_21k?: string | null
          pace_5k?: string | null
          resting_hr?: number | null
          runner_id: string
          strength_score?: number | null
          updated_at?: string
          vo2max_estimate?: number | null
          weight_kg?: number | null
        }
        Update: {
          anaerobic_threshold_hr?: number | null
          assessment_date?: string
          assessment_type?: string
          coach_id?: string | null
          created_at?: string
          endurance_score?: number | null
          height_cm?: number | null
          id?: string
          lactate_threshold_pace?: string | null
          max_hr_estimated?: number | null
          mobility_score?: number | null
          observations?: string | null
          overall_score?: number | null
          pace_10k?: string | null
          pace_21k?: string | null
          pace_5k?: string | null
          resting_hr?: number | null
          runner_id?: string
          strength_score?: number | null
          updated_at?: string
          vo2max_estimate?: number | null
          weight_kg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "assessments_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          created_at: string
          entity: string
          entity_id: string
          id: string
          new_value: Json | null
          old_value: Json | null
          user_id: string | null
        }
        Insert: {
          action: string
          created_at?: string
          entity: string
          entity_id: string
          id?: string
          new_value?: Json | null
          old_value?: Json | null
          user_id?: string | null
        }
        Update: {
          action?: string
          created_at?: string
          entity?: string
          entity_id?: string
          id?: string
          new_value?: Json | null
          old_value?: Json | null
          user_id?: string | null
        }
        Relationships: []
      }
      blocked_users: {
        Row: {
          blocked_id: string
          blocker_id: string
          created_at: string
          reason: string | null
        }
        Insert: {
          blocked_id: string
          blocker_id: string
          created_at?: string
          reason?: string | null
        }
        Update: {
          blocked_id?: string
          blocker_id?: string
          created_at?: string
          reason?: string | null
        }
        Relationships: []
      }
      channel_participants: {
        Row: {
          channel_id: string
          id: string
          is_muted: boolean
          joined_at: string
          last_read_at: string
          role: Database["public"]["Enums"]["participant_role"]
          user_id: string
        }
        Insert: {
          channel_id: string
          id?: string
          is_muted?: boolean
          joined_at?: string
          last_read_at?: string
          role?: Database["public"]["Enums"]["participant_role"]
          user_id: string
        }
        Update: {
          channel_id?: string
          id?: string
          is_muted?: boolean
          joined_at?: string
          last_read_at?: string
          role?: Database["public"]["Enums"]["participant_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "channel_participants_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "channel_participants_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "vw_wsr_conversations"
            referencedColumns: ["channel_id"]
          },
          {
            foreignKeyName: "channel_participants_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "wsr_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      channels: {
        Row: {
          avatar_url: string | null
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          is_archived: boolean
          last_message_at: string | null
          name: string | null
          topic: string | null
          type: Database["public"]["Enums"]["channel_type"]
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_archived?: boolean
          last_message_at?: string | null
          name?: string | null
          topic?: string | null
          type: Database["public"]["Enums"]["channel_type"]
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_archived?: boolean
          last_message_at?: string | null
          name?: string | null
          topic?: string | null
          type?: Database["public"]["Enums"]["channel_type"]
          updated_at?: string
        }
        Relationships: []
      }
      checkin_tokens: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          runner_id: string
          token: string
          used_at: string | null
        }
        Insert: {
          created_at?: string
          expires_at?: string
          id?: string
          runner_id: string
          token?: string
          used_at?: string | null
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          runner_id?: string
          token?: string
          used_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "checkin_tokens_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      checkins: {
        Row: {
          created_at: string
          energy: number
          id: string
          motivation: number
          note: string | null
          pain: number
          sleep: number
          trainings_completed: number
          user_id: string
          week_start: string
        }
        Insert: {
          created_at?: string
          energy: number
          id?: string
          motivation: number
          note?: string | null
          pain: number
          sleep: number
          trainings_completed?: number
          user_id: string
          week_start?: string
        }
        Update: {
          created_at?: string
          energy?: number
          id?: string
          motivation?: number
          note?: string | null
          pain?: number
          sleep?: number
          trainings_completed?: number
          user_id?: string
          week_start?: string
        }
        Relationships: []
      }
      emotional_checkins: {
        Row: {
          created_at: string
          energy: number
          id: string
          mood: string
          note: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          energy: number
          id?: string
          mood: string
          note?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          energy?: number
          id?: string
          mood?: string
          note?: string | null
          user_id?: string
        }
        Relationships: []
      }
      event_code_pool: {
        Row: {
          codigo: string
          created_at: string
          distancia: string | null
          id: string
          sponsor_event_id: string
          tipo_beneficio: string
          usado: boolean
        }
        Insert: {
          codigo: string
          created_at?: string
          distancia?: string | null
          id?: string
          sponsor_event_id: string
          tipo_beneficio: string
          usado?: boolean
        }
        Update: {
          codigo?: string
          created_at?: string
          distancia?: string | null
          id?: string
          sponsor_event_id?: string
          tipo_beneficio?: string
          usado?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "event_code_pool_sponsor_event_id_fkey"
            columns: ["sponsor_event_id"]
            isOneToOne: false
            referencedRelation: "sponsor_events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_winners: {
        Row: {
          codigo: string | null
          created_at: string
          distancia: string | null
          email_externo: string | null
          fecha_asignacion: string
          id: string
          nombre_externo: string | null
          origen_entrada: string | null
          runner_id: string | null
          sponsor_event_id: string
          tipo_beneficio: string
          updated_at: string
        }
        Insert: {
          codigo?: string | null
          created_at?: string
          distancia?: string | null
          email_externo?: string | null
          fecha_asignacion?: string
          id?: string
          nombre_externo?: string | null
          origen_entrada?: string | null
          runner_id?: string | null
          sponsor_event_id: string
          tipo_beneficio: string
          updated_at?: string
        }
        Update: {
          codigo?: string | null
          created_at?: string
          distancia?: string | null
          email_externo?: string | null
          fecha_asignacion?: string
          id?: string
          nombre_externo?: string | null
          origen_entrada?: string | null
          runner_id?: string | null
          sponsor_event_id?: string
          tipo_beneficio?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_winners_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_winners_sponsor_event_id_fkey"
            columns: ["sponsor_event_id"]
            isOneToOne: false
            referencedRelation: "sponsor_events"
            referencedColumns: ["id"]
          },
        ]
      }
      feed_posts: {
        Row: {
          author_id: string
          body: string | null
          created_at: string
          id: string
          likes_count: number
          media_urls: string[]
          post_type: Database["public"]["Enums"]["post_type"]
          ref_id: string | null
          visibility: Database["public"]["Enums"]["post_visibility"]
        }
        Insert: {
          author_id: string
          body?: string | null
          created_at?: string
          id?: string
          likes_count?: number
          media_urls?: string[]
          post_type: Database["public"]["Enums"]["post_type"]
          ref_id?: string | null
          visibility?: Database["public"]["Enums"]["post_visibility"]
        }
        Update: {
          author_id?: string
          body?: string | null
          created_at?: string
          id?: string
          likes_count?: number
          media_urls?: string[]
          post_type?: Database["public"]["Enums"]["post_type"]
          ref_id?: string | null
          visibility?: Database["public"]["Enums"]["post_visibility"]
        }
        Relationships: []
      }
      follows: {
        Row: {
          created_at: string
          follower_id: string
          following_id: string
        }
        Insert: {
          created_at?: string
          follower_id: string
          following_id: string
        }
        Update: {
          created_at?: string
          follower_id?: string
          following_id?: string
        }
        Relationships: []
      }
      gdpr_deletion_log: {
        Row: {
          created_at: string
          deleted_at: string
          id: string
          reason: string
          requested_by: string | null
          runner_id: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string
          id?: string
          reason?: string
          requested_by?: string | null
          runner_id: string
        }
        Update: {
          created_at?: string
          deleted_at?: string
          id?: string
          reason?: string
          requested_by?: string | null
          runner_id?: string
        }
        Relationships: []
      }
      health_alerts: {
        Row: {
          alert_type: string
          check_in_id: string | null
          created_at: string
          id: string
          reason: string
          resolved_at: string | null
          resolved_by: string | null
          runner_id: string
          session_id: string | null
          severity: string
          status: string
        }
        Insert: {
          alert_type: string
          check_in_id?: string | null
          created_at?: string
          id?: string
          reason: string
          resolved_at?: string | null
          resolved_by?: string | null
          runner_id: string
          session_id?: string | null
          severity?: string
          status?: string
        }
        Update: {
          alert_type?: string
          check_in_id?: string | null
          created_at?: string
          id?: string
          reason?: string
          resolved_at?: string | null
          resolved_by?: string | null
          runner_id?: string
          session_id?: string | null
          severity?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "health_alerts_check_in_id_fkey"
            columns: ["check_in_id"]
            isOneToOne: false
            referencedRelation: "plan_check_ins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "health_alerts_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "health_alerts_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "session_results"
            referencedColumns: ["id"]
          },
        ]
      }
      health_profiles: {
        Row: {
          clinic_affiliation: string | null
          created_at: string
          emergency_name: string | null
          emergency_phone: string | null
          has_active_injury: boolean
          has_bone_condition: boolean
          has_cholesterol: boolean
          has_diabetes: boolean
          has_heart_history: boolean
          has_hypertension: boolean
          has_insulin_resistance: boolean
          has_joint_condition: boolean
          id: string
          injury_detail: string | null
          is_smoker: boolean
          last_updated_by: string | null
          medication_detail: string | null
          profile_complete: boolean
          runner_id: string
          source_anamnesis_id: string | null
          takes_medication: boolean
          updated_at: string
        }
        Insert: {
          clinic_affiliation?: string | null
          created_at?: string
          emergency_name?: string | null
          emergency_phone?: string | null
          has_active_injury?: boolean
          has_bone_condition?: boolean
          has_cholesterol?: boolean
          has_diabetes?: boolean
          has_heart_history?: boolean
          has_hypertension?: boolean
          has_insulin_resistance?: boolean
          has_joint_condition?: boolean
          id?: string
          injury_detail?: string | null
          is_smoker?: boolean
          last_updated_by?: string | null
          medication_detail?: string | null
          profile_complete?: boolean
          runner_id: string
          source_anamnesis_id?: string | null
          takes_medication?: boolean
          updated_at?: string
        }
        Update: {
          clinic_affiliation?: string | null
          created_at?: string
          emergency_name?: string | null
          emergency_phone?: string | null
          has_active_injury?: boolean
          has_bone_condition?: boolean
          has_cholesterol?: boolean
          has_diabetes?: boolean
          has_heart_history?: boolean
          has_hypertension?: boolean
          has_insulin_resistance?: boolean
          has_joint_condition?: boolean
          id?: string
          injury_detail?: string | null
          is_smoker?: boolean
          last_updated_by?: string | null
          medication_detail?: string | null
          profile_complete?: boolean
          runner_id?: string
          source_anamnesis_id?: string | null
          takes_medication?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "health_profiles_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: true
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      legacy_web_registrations: {
        Row: {
          app_registration_id: string | null
          asistio: boolean
          condicion_medica: string | null
          contacto_emergencia: string
          created_at: string
          estado_reserva: string
          fecha_inscripcion: string
          id: string
          migrated_at: string
          reconciled: boolean
          respuestas_extra: Json | null
          runner_id: string | null
          training_ref_id: string | null
          updated_at: string
          web_id: string | null
        }
        Insert: {
          app_registration_id?: string | null
          asistio?: boolean
          condicion_medica?: string | null
          contacto_emergencia?: string
          created_at?: string
          estado_reserva?: string
          fecha_inscripcion?: string
          id?: string
          migrated_at?: string
          reconciled?: boolean
          respuestas_extra?: Json | null
          runner_id?: string | null
          training_ref_id?: string | null
          updated_at?: string
          web_id?: string | null
        }
        Update: {
          app_registration_id?: string | null
          asistio?: boolean
          condicion_medica?: string | null
          contacto_emergencia?: string
          created_at?: string
          estado_reserva?: string
          fecha_inscripcion?: string
          id?: string
          migrated_at?: string
          reconciled?: boolean
          respuestas_extra?: Json | null
          runner_id?: string | null
          training_ref_id?: string | null
          updated_at?: string
          web_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "legacy_web_registrations_app_registration_id_fkey"
            columns: ["app_registration_id"]
            isOneToOne: false
            referencedRelation: "web_registrations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "legacy_web_registrations_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      legacy_web_trainings: {
        Row: {
          app_training_id: string | null
          created_at: string
          cupos_totales: number | null
          estado: string
          fecha_hora: string
          id: string
          migrated_at: string
          preguntas_extra: Json | null
          reconciled: boolean
          titulo_entrenamiento: string
          ubicacion: string | null
          updated_at: string
          web_id: string | null
        }
        Insert: {
          app_training_id?: string | null
          created_at?: string
          cupos_totales?: number | null
          estado?: string
          fecha_hora: string
          id?: string
          migrated_at?: string
          preguntas_extra?: Json | null
          reconciled?: boolean
          titulo_entrenamiento: string
          ubicacion?: string | null
          updated_at?: string
          web_id?: string | null
        }
        Update: {
          app_training_id?: string | null
          created_at?: string
          cupos_totales?: number | null
          estado?: string
          fecha_hora?: string
          id?: string
          migrated_at?: string
          preguntas_extra?: Json | null
          reconciled?: boolean
          titulo_entrenamiento?: string
          ubicacion?: string | null
          updated_at?: string
          web_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "legacy_web_trainings_app_training_id_fkey"
            columns: ["app_training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "legacy_web_trainings_app_training_id_fkey"
            columns: ["app_training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "legacy_web_trainings_app_training_id_fkey"
            columns: ["app_training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      loyalty_tiers: {
        Row: {
          color_hex: string
          display_name: string
          emoji: string
          max_points: number | null
          min_points: number
          perks: Json
          sort_order: number
          tier: Database["public"]["Enums"]["loyalty_tier"]
        }
        Insert: {
          color_hex: string
          display_name: string
          emoji: string
          max_points?: number | null
          min_points: number
          perks?: Json
          sort_order: number
          tier: Database["public"]["Enums"]["loyalty_tier"]
        }
        Update: {
          color_hex?: string
          display_name?: string
          emoji?: string
          max_points?: number | null
          min_points?: number
          perks?: Json
          sort_order?: number
          tier?: Database["public"]["Enums"]["loyalty_tier"]
        }
        Relationships: []
      }
      messages: {
        Row: {
          body: string
          channel_id: string
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          id: string
          kind: Database["public"]["Enums"]["message_kind"]
          sender_id: string
        }
        Insert: {
          body: string
          channel_id: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["message_kind"]
          sender_id: string
        }
        Update: {
          body?: string
          channel_id?: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["message_kind"]
          sender_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "messages_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "vw_wsr_conversations"
            referencedColumns: ["channel_id"]
          },
          {
            foreignKeyName: "messages_channel_id_fkey"
            columns: ["channel_id"]
            isOneToOne: false
            referencedRelation: "wsr_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          id: string
          is_read: boolean
          kind: Database["public"]["Enums"]["notification_kind"]
          ref_id: string | null
          ref_type: string | null
          title: string
          user_id: string
        }
        Insert: {
          body?: string
          created_at?: string
          id?: string
          is_read?: boolean
          kind?: Database["public"]["Enums"]["notification_kind"]
          ref_id?: string | null
          ref_type?: string | null
          title: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          is_read?: boolean
          kind?: Database["public"]["Enums"]["notification_kind"]
          ref_id?: string | null
          ref_type?: string | null
          title?: string
          user_id?: string
        }
        Relationships: []
      }
      pacers: {
        Row: {
          avatar_url: string
          bio: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          specialty: string
          user_id: string | null
        }
        Insert: {
          avatar_url?: string
          bio?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          specialty?: string
          user_id?: string | null
        }
        Update: {
          avatar_url?: string
          bio?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          specialty?: string
          user_id?: string | null
        }
        Relationships: []
      }
      partner_benefit_claims: {
        Row: {
          claimed_at: string
          created_at: string
          id: string
          partner_slug: string
          runner_id: string
          updated_at: string
        }
        Insert: {
          claimed_at?: string
          created_at?: string
          id?: string
          partner_slug: string
          runner_id: string
          updated_at?: string
        }
        Update: {
          claimed_at?: string
          created_at?: string
          id?: string
          partner_slug?: string
          runner_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "partner_benefit_claims_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      personal_trainings: {
        Row: {
          coach_id: string
          completed_at: string | null
          created_at: string
          description: string | null
          id: string
          runner_feeling: Database["public"]["Enums"]["training_feeling"] | null
          runner_id: string
          runner_notes: string | null
          scheduled_date: string
          status: Database["public"]["Enums"]["personal_training_status"]
          target_distance_km: number | null
          target_notes: string | null
          title: string
          training_type: string | null
        }
        Insert: {
          coach_id: string
          completed_at?: string | null
          created_at?: string
          description?: string | null
          id?: string
          runner_feeling?:
            | Database["public"]["Enums"]["training_feeling"]
            | null
          runner_id: string
          runner_notes?: string | null
          scheduled_date: string
          status?: Database["public"]["Enums"]["personal_training_status"]
          target_distance_km?: number | null
          target_notes?: string | null
          title: string
          training_type?: string | null
        }
        Update: {
          coach_id?: string
          completed_at?: string | null
          created_at?: string
          description?: string | null
          id?: string
          runner_feeling?:
            | Database["public"]["Enums"]["training_feeling"]
            | null
          runner_id?: string
          runner_notes?: string | null
          scheduled_date?: string
          status?: Database["public"]["Enums"]["personal_training_status"]
          target_distance_km?: number | null
          target_notes?: string | null
          title?: string
          training_type?: string | null
        }
        Relationships: []
      }
      plan_check_ins: {
        Row: {
          comments: string | null
          compliance_pct: number | null
          created_at: string
          energy: number
          id: string
          life_changes: boolean
          life_changes_detail: string | null
          motivation: number
          pain: number
          pain_location: string | null
          plan_id: string | null
          runner_id: string
          sessions_completed: number
          sessions_planned: number
          sleep_quality: number
          week_start: string
        }
        Insert: {
          comments?: string | null
          compliance_pct?: number | null
          created_at?: string
          energy: number
          id?: string
          life_changes?: boolean
          life_changes_detail?: string | null
          motivation: number
          pain: number
          pain_location?: string | null
          plan_id?: string | null
          runner_id: string
          sessions_completed: number
          sessions_planned: number
          sleep_quality: number
          week_start?: string
        }
        Update: {
          comments?: string | null
          compliance_pct?: number | null
          created_at?: string
          energy?: number
          id?: string
          life_changes?: boolean
          life_changes_detail?: string | null
          motivation?: number
          pain?: number
          pain_location?: string | null
          plan_id?: string | null
          runner_id?: string
          sessions_completed?: number
          sessions_planned?: number
          sleep_quality?: number
          week_start?: string
        }
        Relationships: [
          {
            foreignKeyName: "plan_check_ins_plan_id_fk"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plan_check_ins_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      plans: {
        Row: {
          approved_at: string | null
          coach_id: string | null
          coach_message: string | null
          created_at: string
          current_level: string
          days_per_week: number
          delivered_at: string | null
          delivered_to: string | null
          generated_at: string | null
          goal: string | null
          id: string
          notes: string | null
          parent_plan_id: string | null
          pdf_generated_at: string | null
          pdf_url: string | null
          pdf_version: number
          runner_id: string
          status: string
          title: string
          updated_at: string
          version: number
          version_tag: string
          weekly_km_base: number | null
        }
        Insert: {
          approved_at?: string | null
          coach_id?: string | null
          coach_message?: string | null
          created_at?: string
          current_level?: string
          days_per_week?: number
          delivered_at?: string | null
          delivered_to?: string | null
          generated_at?: string | null
          goal?: string | null
          id?: string
          notes?: string | null
          parent_plan_id?: string | null
          pdf_generated_at?: string | null
          pdf_url?: string | null
          pdf_version?: number
          runner_id: string
          status?: string
          title: string
          updated_at?: string
          version?: number
          version_tag?: string
          weekly_km_base?: number | null
        }
        Update: {
          approved_at?: string | null
          coach_id?: string | null
          coach_message?: string | null
          created_at?: string
          current_level?: string
          days_per_week?: number
          delivered_at?: string | null
          delivered_to?: string | null
          generated_at?: string | null
          goal?: string | null
          id?: string
          notes?: string | null
          parent_plan_id?: string | null
          pdf_generated_at?: string | null
          pdf_url?: string | null
          pdf_version?: number
          runner_id?: string
          status?: string
          title?: string
          updated_at?: string
          version?: number
          version_tag?: string
          weekly_km_base?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "plans_parent_plan_id_fkey"
            columns: ["parent_plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plans_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      point_campaigns: {
        Row: {
          applies_to_event: string | null
          bonus_points: number
          description: string | null
          ends_at: string
          id: string
          is_active: boolean
          multiplier: number
          name: string
          starts_at: string
        }
        Insert: {
          applies_to_event?: string | null
          bonus_points?: number
          description?: string | null
          ends_at: string
          id?: string
          is_active?: boolean
          multiplier?: number
          name: string
          starts_at: string
        }
        Update: {
          applies_to_event?: string | null
          bonus_points?: number
          description?: string | null
          ends_at?: string
          id?: string
          is_active?: boolean
          multiplier?: number
          name?: string
          starts_at?: string
        }
        Relationships: []
      }
      point_rules: {
        Row: {
          category: string
          description: string
          display_name: string
          event_type: string
          is_active: boolean
          max_per_period: number | null
          period: string | null
          points: number
        }
        Insert: {
          category: string
          description: string
          display_name: string
          event_type: string
          is_active?: boolean
          max_per_period?: number | null
          period?: string | null
          points: number
        }
        Update: {
          category?: string
          description?: string
          display_name?: string
          event_type?: string
          is_active?: boolean
          max_per_period?: number | null
          period?: string | null
          points?: number
        }
        Relationships: []
      }
      point_transactions: {
        Row: {
          created_at: string
          description: string
          event_type: string
          id: string
          points: number
          reference_id: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          description: string
          event_type: string
          id?: string
          points: number
          reference_id?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          description?: string
          event_type?: string
          id?: string
          points?: number
          reference_id?: string | null
          user_id?: string
        }
        Relationships: []
      }
      post_likes: {
        Row: {
          created_at: string
          post_id: string
          reaction: Database["public"]["Enums"]["reaction_kind"]
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          reaction?: Database["public"]["Enums"]["reaction_kind"]
          user_id: string
        }
        Update: {
          created_at?: string
          post_id?: string
          reaction?: Database["public"]["Enums"]["reaction_kind"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "feed_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "vw_social_feed"
            referencedColumns: ["event_id"]
          },
        ]
      }
      reactivation_log: {
        Row: {
          id: string
          sent_at: string
          stage: number
          user_id: string
        }
        Insert: {
          id?: string
          sent_at?: string
          stage: number
          user_id: string
        }
        Update: {
          id?: string
          sent_at?: string
          stage?: number
          user_id?: string
        }
        Relationships: []
      }
      referrals: {
        Row: {
          created_at: string
          id: string
          qualified_at: string | null
          referral_code: string
          referred_email: string | null
          referred_id: string | null
          referrer_id: string
          status: Database["public"]["Enums"]["referral_status"]
        }
        Insert: {
          created_at?: string
          id?: string
          qualified_at?: string | null
          referral_code?: string
          referred_email?: string | null
          referred_id?: string | null
          referrer_id: string
          status?: Database["public"]["Enums"]["referral_status"]
        }
        Update: {
          created_at?: string
          id?: string
          qualified_at?: string | null
          referral_code?: string
          referred_email?: string | null
          referred_id?: string | null
          referrer_id?: string
          status?: Database["public"]["Enums"]["referral_status"]
        }
        Relationships: []
      }
      registrations: {
        Row: {
          anexo_a_aceptado_en: string | null
          anexo_a_requerido: boolean
          anexo_a_vigencia: string | null
          cancelled_at: string | null
          condiciones_declaradas: string[] | null
          id: string
          registered_at: string
          status: Database["public"]["Enums"]["registration_status"]
          tiene_condicion_medica: boolean
          training_id: string
          user_id: string
        }
        Insert: {
          anexo_a_aceptado_en?: string | null
          anexo_a_requerido?: boolean
          anexo_a_vigencia?: string | null
          cancelled_at?: string | null
          condiciones_declaradas?: string[] | null
          id?: string
          registered_at?: string
          status?: Database["public"]["Enums"]["registration_status"]
          tiene_condicion_medica?: boolean
          training_id: string
          user_id: string
        }
        Update: {
          anexo_a_aceptado_en?: string | null
          anexo_a_requerido?: boolean
          anexo_a_vigencia?: string | null
          cancelled_at?: string | null
          condiciones_declaradas?: string[] | null
          id?: string
          registered_at?: string
          status?: Database["public"]["Enums"]["registration_status"]
          tiene_condicion_medica?: boolean
          training_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "registrations_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registrations_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registrations_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      reported_content: {
        Row: {
          content_id: string | null
          content_type: Database["public"]["Enums"]["report_target"]
          created_at: string
          details: string | null
          id: string
          reason: Database["public"]["Enums"]["report_reason"]
          reported_user_id: string
          reporter_id: string
          resolution_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["report_status"]
        }
        Insert: {
          content_id?: string | null
          content_type: Database["public"]["Enums"]["report_target"]
          created_at?: string
          details?: string | null
          id?: string
          reason: Database["public"]["Enums"]["report_reason"]
          reported_user_id: string
          reporter_id: string
          resolution_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["report_status"]
        }
        Update: {
          content_id?: string | null
          content_type?: Database["public"]["Enums"]["report_target"]
          created_at?: string
          details?: string | null
          id?: string
          reason?: Database["public"]["Enums"]["report_reason"]
          reported_user_id?: string
          reporter_id?: string
          resolution_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["report_status"]
        }
        Relationships: []
      }
      reward_redemptions: {
        Row: {
          admin_notes: string | null
          approved_at: string | null
          delivered_at: string | null
          id: string
          points_spent: number
          redemption_code: string | null
          requested_at: string
          reward_id: string
          status: Database["public"]["Enums"]["redemption_status"]
          user_id: string
        }
        Insert: {
          admin_notes?: string | null
          approved_at?: string | null
          delivered_at?: string | null
          id?: string
          points_spent: number
          redemption_code?: string | null
          requested_at?: string
          reward_id: string
          status?: Database["public"]["Enums"]["redemption_status"]
          user_id: string
        }
        Update: {
          admin_notes?: string | null
          approved_at?: string | null
          delivered_at?: string | null
          id?: string
          points_spent?: number
          redemption_code?: string | null
          requested_at?: string
          reward_id?: string
          status?: Database["public"]["Enums"]["redemption_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reward_redemptions_reward_id_fkey"
            columns: ["reward_id"]
            isOneToOne: false
            referencedRelation: "rewards_catalog"
            referencedColumns: ["id"]
          },
        ]
      }
      rewards_catalog: {
        Row: {
          category: string
          created_at: string
          description: string
          emoji: string
          id: string
          image_url: string | null
          is_active: boolean
          name: string
          points_cost: number
          redemption_instructions: string
          required_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          sponsor_id: string | null
          stock: number | null
        }
        Insert: {
          category: string
          created_at?: string
          description: string
          emoji?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name: string
          points_cost: number
          redemption_instructions: string
          required_tier?: Database["public"]["Enums"]["loyalty_tier"] | null
          sponsor_id?: string | null
          stock?: number | null
        }
        Update: {
          category?: string
          created_at?: string
          description?: string
          emoji?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          name?: string
          points_cost?: number
          redemption_instructions?: string
          required_tier?: Database["public"]["Enums"]["loyalty_tier"] | null
          sponsor_id?: string | null
          stock?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "rewards_catalog_sponsor_id_fkey"
            columns: ["sponsor_id"]
            isOneToOne: false
            referencedRelation: "sponsors"
            referencedColumns: ["id"]
          },
        ]
      }
      runner_profiles: {
        Row: {
          created_at: string
          id: string
          is_verified: boolean
          linked_at: string
          linked_by: string | null
          runner_id: string
          updated_at: string
          user_profile_id: string | null
          verification_note: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          is_verified?: boolean
          linked_at?: string
          linked_by?: string | null
          runner_id: string
          updated_at?: string
          user_profile_id?: string | null
          verification_note?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          is_verified?: boolean
          linked_at?: string
          linked_by?: string | null
          runner_id?: string
          updated_at?: string
          user_profile_id?: string | null
          verification_note?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "runner_profiles_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: true
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runner_profiles_user_profile_id_fkey"
            columns: ["user_profile_id"]
            isOneToOne: true
            referencedRelation: "loyalty_leaderboard"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runner_profiles_user_profile_id_fkey"
            columns: ["user_profile_id"]
            isOneToOne: true
            referencedRelation: "public_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runner_profiles_user_profile_id_fkey"
            columns: ["user_profile_id"]
            isOneToOne: true
            referencedRelation: "user_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runner_profiles_user_profile_id_fkey"
            columns: ["user_profile_id"]
            isOneToOne: true
            referencedRelation: "user_tier_progress"
            referencedColumns: ["user_id"]
          },
        ]
      }
      runners: {
        Row: {
          acepta_marketing: boolean
          autoriza_datos: boolean | null
          autoriza_imagen: boolean
          autoriza_perfil_sponsors: boolean
          coach_id: string | null
          comuna: string | null
          consent_version: string | null
          consents_updated_at: string | null
          control_envio: string | null
          created_at: string
          email: string
          estado_civil: string | null
          fecha_nacimiento: string | null
          formato_contenido: string | null
          frecuencia_deporte: string | null
          id: string
          instagram_usuario: string | null
          interaccion_marcas: string | null
          intereses_hobbies: string | null
          nivel_educativo: string | null
          nombre_apellido: string
          ocupacion: string | null
          parental_consent_confirmed_at: string | null
          parental_consent_confirmed_by: string | null
          parental_consent_sensitive_data: boolean
          participa_carreras: string | null
          productos_interes: string | null
          redes_sociales: string | null
          sigue_marcas: string | null
          status: string | null
          talla_polera: string | null
          telefono: string | null
          tiene_hijos: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          acepta_marketing?: boolean
          autoriza_datos?: boolean | null
          autoriza_imagen?: boolean
          autoriza_perfil_sponsors?: boolean
          coach_id?: string | null
          comuna?: string | null
          consent_version?: string | null
          consents_updated_at?: string | null
          control_envio?: string | null
          created_at?: string
          email: string
          estado_civil?: string | null
          fecha_nacimiento?: string | null
          formato_contenido?: string | null
          frecuencia_deporte?: string | null
          id?: string
          instagram_usuario?: string | null
          interaccion_marcas?: string | null
          intereses_hobbies?: string | null
          nivel_educativo?: string | null
          nombre_apellido: string
          ocupacion?: string | null
          parental_consent_confirmed_at?: string | null
          parental_consent_confirmed_by?: string | null
          parental_consent_sensitive_data?: boolean
          participa_carreras?: string | null
          productos_interes?: string | null
          redes_sociales?: string | null
          sigue_marcas?: string | null
          status?: string | null
          talla_polera?: string | null
          telefono?: string | null
          tiene_hijos?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          acepta_marketing?: boolean
          autoriza_datos?: boolean | null
          autoriza_imagen?: boolean
          autoriza_perfil_sponsors?: boolean
          coach_id?: string | null
          comuna?: string | null
          consent_version?: string | null
          consents_updated_at?: string | null
          control_envio?: string | null
          created_at?: string
          email?: string
          estado_civil?: string | null
          fecha_nacimiento?: string | null
          formato_contenido?: string | null
          frecuencia_deporte?: string | null
          id?: string
          instagram_usuario?: string | null
          interaccion_marcas?: string | null
          intereses_hobbies?: string | null
          nivel_educativo?: string | null
          nombre_apellido?: string
          ocupacion?: string | null
          parental_consent_confirmed_at?: string | null
          parental_consent_confirmed_by?: string | null
          parental_consent_sensitive_data?: boolean
          participa_carreras?: string | null
          productos_interes?: string | null
          redes_sociales?: string | null
          sigue_marcas?: string | null
          status?: string | null
          talla_polera?: string | null
          telefono?: string | null
          tiene_hijos?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      scores: {
        Row: {
          assessment_date: string
          created_at: string
          endurance_score: number | null
          id: string
          lactate_threshold_pace: string | null
          mobility_score: number | null
          notes: string | null
          overall_score: number | null
          plan_id: string | null
          runner_id: string
          strength_score: number | null
          vo2max_estimate: number | null
        }
        Insert: {
          assessment_date?: string
          created_at?: string
          endurance_score?: number | null
          id?: string
          lactate_threshold_pace?: string | null
          mobility_score?: number | null
          notes?: string | null
          overall_score?: number | null
          plan_id?: string | null
          runner_id: string
          strength_score?: number | null
          vo2max_estimate?: number | null
        }
        Update: {
          assessment_date?: string
          created_at?: string
          endurance_score?: number | null
          id?: string
          lactate_threshold_pace?: string | null
          mobility_score?: number | null
          notes?: string | null
          overall_score?: number | null
          plan_id?: string | null
          runner_id?: string
          strength_score?: number | null
          vo2max_estimate?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "scores_plan_id_fk"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "scores_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
        ]
      }
      session_results: {
        Row: {
          actual_distance_km: number | null
          actual_duration_min: number | null
          actual_rpe: number | null
          completed_at: string
          created_at: string
          id: string
          notes: string | null
          pain_location: string | null
          pain_score: number
          plan_id: string | null
          runner_id: string
          source: string
          training_session_id: string
        }
        Insert: {
          actual_distance_km?: number | null
          actual_duration_min?: number | null
          actual_rpe?: number | null
          completed_at?: string
          created_at?: string
          id?: string
          notes?: string | null
          pain_location?: string | null
          pain_score?: number
          plan_id?: string | null
          runner_id: string
          source?: string
          training_session_id: string
        }
        Update: {
          actual_distance_km?: number | null
          actual_duration_min?: number | null
          actual_rpe?: number | null
          completed_at?: string
          created_at?: string
          id?: string
          notes?: string | null
          pain_location?: string | null
          pain_score?: number
          plan_id?: string | null
          runner_id?: string
          source?: string
          training_session_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "session_results_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_results_runner_id_fkey"
            columns: ["runner_id"]
            isOneToOne: false
            referencedRelation: "runners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_results_training_session_id_fkey"
            columns: ["training_session_id"]
            isOneToOne: true
            referencedRelation: "training_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      sponsor_events: {
        Row: {
          created_at: string
          cupos_descuentos: number
          cupos_entradas: number
          estado: string
          fecha_carrera: string | null
          id: string
          nombre_carrera: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          cupos_descuentos?: number
          cupos_entradas?: number
          estado?: string
          fecha_carrera?: string | null
          id?: string
          nombre_carrera: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          cupos_descuentos?: number
          cupos_entradas?: number
          estado?: string
          fecha_carrera?: string | null
          id?: string
          nombre_carrera?: string
          updated_at?: string
        }
        Relationships: []
      }
      sponsors: {
        Row: {
          banner_url: string | null
          id: string
          is_active: boolean
          logo_url: string
          name: string
          website_url: string | null
        }
        Insert: {
          banner_url?: string | null
          id?: string
          is_active?: boolean
          logo_url?: string
          name: string
          website_url?: string | null
        }
        Update: {
          banner_url?: string | null
          id?: string
          is_active?: boolean
          logo_url?: string
          name?: string
          website_url?: string | null
        }
        Relationships: []
      }
      super_admin_emails: {
        Row: {
          email: string
          granted_at: string
        }
        Insert: {
          email: string
          granted_at?: string
        }
        Update: {
          email?: string
          granted_at?: string
        }
        Relationships: []
      }
      training_checkins: {
        Row: {
          checked_in_at: string
          checked_out_at: string | null
          id: string
          training_id: string
          user_id: string
        }
        Insert: {
          checked_in_at?: string
          checked_out_at?: string | null
          id?: string
          training_id: string
          user_id: string
        }
        Update: {
          checked_in_at?: string
          checked_out_at?: string | null
          id?: string
          training_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_checkins_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_checkins_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_checkins_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      training_group_members: {
        Row: {
          group_id: string
          id: string
          joined_at: string
          rol: string
          user_id: string
        }
        Insert: {
          group_id: string
          id?: string
          joined_at?: string
          rol?: string
          user_id: string
        }
        Update: {
          group_id?: string
          id?: string
          joined_at?: string
          rol?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "training_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      training_groups: {
        Row: {
          capacidad_max: number
          coach_id: string | null
          color: string
          created_at: string
          id: string
          nombre: string
          orden: number
          pacer_id: string | null
          training_id: string
        }
        Insert: {
          capacidad_max?: number
          coach_id?: string | null
          color?: string
          created_at?: string
          id?: string
          nombre?: string
          orden?: number
          pacer_id?: string | null
          training_id: string
        }
        Update: {
          capacidad_max?: number
          coach_id?: string | null
          color?: string
          created_at?: string
          id?: string
          nombre?: string
          orden?: number
          pacer_id?: string | null
          training_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_groups_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_groups_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_groups_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      training_leaders: {
        Row: {
          created_at: string
          id: string
          role: string
          training_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: string
          training_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: string
          training_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_leaders_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_leaders_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_leaders_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      training_pacers: {
        Row: {
          created_at: string
          pacer_id: string
          rol: string
          training_id: string
        }
        Insert: {
          created_at?: string
          pacer_id: string
          rol?: string
          training_id: string
        }
        Update: {
          created_at?: string
          pacer_id?: string
          rol?: string
          training_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_pacers_pacer_id_fkey"
            columns: ["pacer_id"]
            isOneToOne: false
            referencedRelation: "web_registrations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_pacers_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_pacers_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_pacers_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      training_sessions: {
        Row: {
          coach_notes: string | null
          completed_at: string | null
          cooldown_desc: string | null
          created_at: string
          day_of_week: number
          description: string | null
          distance_km: number | null
          duration_min: number | null
          id: string
          intensity: string
          main_desc: string | null
          pace_target: string | null
          rpe_target: number | null
          session_type: string
          status: string
          title: string | null
          updated_at: string
          warmup_desc: string | null
          week_id: string
        }
        Insert: {
          coach_notes?: string | null
          completed_at?: string | null
          cooldown_desc?: string | null
          created_at?: string
          day_of_week: number
          description?: string | null
          distance_km?: number | null
          duration_min?: number | null
          id?: string
          intensity?: string
          main_desc?: string | null
          pace_target?: string | null
          rpe_target?: number | null
          session_type?: string
          status?: string
          title?: string | null
          updated_at?: string
          warmup_desc?: string | null
          week_id: string
        }
        Update: {
          coach_notes?: string | null
          completed_at?: string | null
          cooldown_desc?: string | null
          created_at?: string
          day_of_week?: number
          description?: string | null
          distance_km?: number | null
          duration_min?: number | null
          id?: string
          intensity?: string
          main_desc?: string | null
          pace_target?: string | null
          rpe_target?: number | null
          session_type?: string
          status?: string
          title?: string | null
          updated_at?: string
          warmup_desc?: string | null
          week_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_sessions_week_id_fkey"
            columns: ["week_id"]
            isOneToOne: false
            referencedRelation: "training_weeks"
            referencedColumns: ["id"]
          },
        ]
      }
      training_sos_alerts: {
        Row: {
          id: string
          lat: number | null
          lng: number | null
          resolved_at: string | null
          resolved_by: string | null
          runner_id: string
          sent_at: string
          training_id: string
        }
        Insert: {
          id?: string
          lat?: number | null
          lng?: number | null
          resolved_at?: string | null
          resolved_by?: string | null
          runner_id: string
          sent_at?: string
          training_id: string
        }
        Update: {
          id?: string
          lat?: number | null
          lng?: number | null
          resolved_at?: string | null
          resolved_by?: string | null
          runner_id?: string
          sent_at?: string
          training_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_sos_alerts_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_sos_alerts_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_sos_alerts_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      training_surveys: {
        Row: {
          free_text: string | null
          id: string
          satisfaction_score: number
          submitted_at: string
          training_id: string
          user_id: string
          would_recommend: boolean
        }
        Insert: {
          free_text?: string | null
          id?: string
          satisfaction_score: number
          submitted_at?: string
          training_id: string
          user_id: string
          would_recommend?: boolean
        }
        Update: {
          free_text?: string | null
          id?: string
          satisfaction_score?: number
          submitted_at?: string
          training_id?: string
          user_id?: string
          would_recommend?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "training_surveys_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_surveys_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "training_surveys_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      training_weeks: {
        Row: {
          created_at: string
          focus: string | null
          id: string
          notes: string | null
          plan_id: string
          updated_at: string
          week_number: number
          week_type: string
          weekly_km_target: number | null
        }
        Insert: {
          created_at?: string
          focus?: string | null
          id?: string
          notes?: string | null
          plan_id: string
          updated_at?: string
          week_number: number
          week_type?: string
          weekly_km_target?: number | null
        }
        Update: {
          created_at?: string
          focus?: string | null
          id?: string
          notes?: string | null
          plan_id?: string
          updated_at?: string
          week_number?: number
          week_type?: string
          weekly_km_target?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "training_weeks_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
        ]
      }
      trainings: {
        Row: {
          coach_id: string | null
          cover_image_url: string | null
          created_at: string
          descripcion: string | null
          description: string | null
          distance_km: number | null
          id: string
          imagen_url: string | null
          latitude: number | null
          location_detail: string | null
          location_maps_url: string | null
          location_name: string
          longitude: number | null
          max_capacity: number
          nivel_objetivo: string | null
          pacer_id: string | null
          pacer_nombre: string | null
          pacer_user_id: string | null
          preguntas_extra: Json | null
          puntos_asistencia: number
          recommended_level: string
          scheduled_at: string
          sponsor_event_id: string | null
          sponsor_id: string | null
          status: Database["public"]["Enums"]["training_status"]
          tipo_entrenamiento: string | null
          title: string
          training_kind: string
          training_type: Database["public"]["Enums"]["training_type"]
        }
        Insert: {
          coach_id?: string | null
          cover_image_url?: string | null
          created_at?: string
          descripcion?: string | null
          description?: string | null
          distance_km?: number | null
          id?: string
          imagen_url?: string | null
          latitude?: number | null
          location_detail?: string | null
          location_maps_url?: string | null
          location_name: string
          longitude?: number | null
          max_capacity?: number
          nivel_objetivo?: string | null
          pacer_id?: string | null
          pacer_nombre?: string | null
          pacer_user_id?: string | null
          preguntas_extra?: Json | null
          puntos_asistencia?: number
          recommended_level?: string
          scheduled_at: string
          sponsor_event_id?: string | null
          sponsor_id?: string | null
          status?: Database["public"]["Enums"]["training_status"]
          tipo_entrenamiento?: string | null
          title: string
          training_kind?: string
          training_type?: Database["public"]["Enums"]["training_type"]
        }
        Update: {
          coach_id?: string | null
          cover_image_url?: string | null
          created_at?: string
          descripcion?: string | null
          description?: string | null
          distance_km?: number | null
          id?: string
          imagen_url?: string | null
          latitude?: number | null
          location_detail?: string | null
          location_maps_url?: string | null
          location_name?: string
          longitude?: number | null
          max_capacity?: number
          nivel_objetivo?: string | null
          pacer_id?: string | null
          pacer_nombre?: string | null
          pacer_user_id?: string | null
          preguntas_extra?: Json | null
          puntos_asistencia?: number
          recommended_level?: string
          scheduled_at?: string
          sponsor_event_id?: string | null
          sponsor_id?: string | null
          status?: Database["public"]["Enums"]["training_status"]
          tipo_entrenamiento?: string | null
          title?: string
          training_kind?: string
          training_type?: Database["public"]["Enums"]["training_type"]
        }
        Relationships: [
          {
            foreignKeyName: "trainings_pacer_id_fkey"
            columns: ["pacer_id"]
            isOneToOne: false
            referencedRelation: "pacers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trainings_sponsor_id_fkey"
            columns: ["sponsor_id"]
            isOneToOne: false
            referencedRelation: "sponsors"
            referencedColumns: ["id"]
          },
        ]
      }
      user_achievements: {
        Row: {
          achievement_id: string
          id: string
          unlocked_at: string
          user_id: string
        }
        Insert: {
          achievement_id: string
          id?: string
          unlocked_at?: string
          user_id: string
        }
        Update: {
          achievement_id?: string
          id?: string
          unlocked_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_achievements_achievement_id_fkey"
            columns: ["achievement_id"]
            isOneToOne: false
            referencedRelation: "achievements"
            referencedColumns: ["id"]
          },
        ]
      }
      user_onboarding: {
        Row: {
          barriers: string[]
          completed_at: string | null
          cycle_opt_in: boolean
          energy_baseline: number | null
          motivations: string[]
          running_relationship: string | null
          support_style: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          barriers?: string[]
          completed_at?: string | null
          cycle_opt_in?: boolean
          energy_baseline?: number | null
          motivations?: string[]
          running_relationship?: string | null
          support_style?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          barriers?: string[]
          completed_at?: string | null
          cycle_opt_in?: boolean
          energy_baseline?: number | null
          motivations?: string[]
          running_relationship?: string | null
          support_style?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_profiles: {
        Row: {
          avatar_url: string | null
          bio: string | null
          birth_date: string | null
          city: string
          created_at: string
          current_tier: Database["public"]["Enums"]["loyalty_tier"]
          email: string
          favorite_distance: string | null
          full_name: string
          id: string
          last_activity_at: string | null
          last_streak_weeks: number
          max_streak_weeks: number
          points_updated_at: string | null
          profile_photo_urls: string[] | null
          push_token: string | null
          running_level: Database["public"]["Enums"]["running_level"]
          running_since: string | null
          total_points: number
          updated_at: string
          why_i_run: string | null
        }
        Insert: {
          avatar_url?: string | null
          bio?: string | null
          birth_date?: string | null
          city?: string
          created_at?: string
          current_tier?: Database["public"]["Enums"]["loyalty_tier"]
          email: string
          favorite_distance?: string | null
          full_name: string
          id: string
          last_activity_at?: string | null
          last_streak_weeks?: number
          max_streak_weeks?: number
          points_updated_at?: string | null
          profile_photo_urls?: string[] | null
          push_token?: string | null
          running_level?: Database["public"]["Enums"]["running_level"]
          running_since?: string | null
          total_points?: number
          updated_at?: string
          why_i_run?: string | null
        }
        Update: {
          avatar_url?: string | null
          bio?: string | null
          birth_date?: string | null
          city?: string
          created_at?: string
          current_tier?: Database["public"]["Enums"]["loyalty_tier"]
          email?: string
          favorite_distance?: string | null
          full_name?: string
          id?: string
          last_activity_at?: string | null
          last_streak_weeks?: number
          max_streak_weeks?: number
          points_updated_at?: string | null
          profile_photo_urls?: string[] | null
          push_token?: string | null
          running_level?: Database["public"]["Enums"]["running_level"]
          running_since?: string | null
          total_points?: number
          updated_at?: string
          why_i_run?: string | null
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          granted_at: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          granted_at?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          granted_at?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      web_registrations: {
        Row: {
          anexo_a_aceptado_en: string | null
          anexo_a_requerido: boolean
          anexo_a_vigencia: string | null
          asistio: boolean
          condicion_medica: string | null
          condiciones_declaradas: string[] | null
          contacto_emergencia: string
          created_via: string
          email: string
          estado_reserva: string
          fecha_inscripcion: string
          id: string
          nombre: string
          respuestas_extra: Json | null
          telefono: string | null
          tiene_condicion_medica: boolean
          training_id: string
          user_id: string | null
        }
        Insert: {
          anexo_a_aceptado_en?: string | null
          anexo_a_requerido?: boolean
          anexo_a_vigencia?: string | null
          asistio?: boolean
          condicion_medica?: string | null
          condiciones_declaradas?: string[] | null
          contacto_emergencia: string
          created_via?: string
          email: string
          estado_reserva?: string
          fecha_inscripcion?: string
          id?: string
          nombre: string
          respuestas_extra?: Json | null
          telefono?: string | null
          tiene_condicion_medica?: boolean
          training_id: string
          user_id?: string | null
        }
        Update: {
          anexo_a_aceptado_en?: string | null
          anexo_a_requerido?: boolean
          anexo_a_vigencia?: string | null
          asistio?: boolean
          condicion_medica?: string | null
          condiciones_declaradas?: string[] | null
          contacto_emergencia?: string
          created_via?: string
          email?: string
          estado_reserva?: string
          fecha_inscripcion?: string
          id?: string
          nombre?: string
          respuestas_extra?: Json | null
          telefono?: string | null
          tiene_condicion_medica?: boolean
          training_id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "web_registrations_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "training_with_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "web_registrations_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "web_registrations_training_id_fkey"
            columns: ["training_id"]
            isOneToOne: false
            referencedRelation: "trainings_web"
            referencedColumns: ["id"]
          },
        ]
      }
      wsr_config: {
        Row: {
          key: string
          value: string
        }
        Insert: {
          key: string
          value: string
        }
        Update: {
          key?: string
          value?: string
        }
        Relationships: []
      }
      wsr_pacers: {
        Row: {
          activo: boolean
          avatar_url: string | null
          bio: string | null
          created_at: string
          id: string
          instagram: string | null
          nombre: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          activo?: boolean
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          id?: string
          instagram?: string | null
          nombre: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          activo?: boolean
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          id?: string
          instagram?: string | null
          nombre?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      feed_activities: {
        Row: {
          activity_type: string | null
          actor_avatar_url: string | null
          actor_name: string | null
          id: string | null
          metadata: Json | null
          occurred_at: string | null
        }
        Relationships: []
      }
      loyalty_leaderboard: {
        Row: {
          avatar_url: string | null
          current_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          full_name: string | null
          id: string | null
          rank: number | null
          tier_color: string | null
          tier_emoji: string | null
          tier_name: string | null
          total_points: number | null
        }
        Relationships: []
      }
      public_profiles: {
        Row: {
          avatar_url: string | null
          bio: string | null
          city: string | null
          current_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          favorite_distance: string | null
          full_name: string | null
          id: string | null
          last_activity_at: string | null
          last_streak_weeks: number | null
          max_streak_weeks: number | null
          profile_photo_urls: string[] | null
          running_level: Database["public"]["Enums"]["running_level"] | null
          running_since: string | null
          why_i_run: string | null
        }
        Insert: {
          avatar_url?: string | null
          bio?: string | null
          city?: string | null
          current_tier?: Database["public"]["Enums"]["loyalty_tier"] | null
          favorite_distance?: string | null
          full_name?: string | null
          id?: string | null
          last_activity_at?: string | null
          last_streak_weeks?: number | null
          max_streak_weeks?: number | null
          profile_photo_urls?: string[] | null
          running_level?: Database["public"]["Enums"]["running_level"] | null
          running_since?: string | null
          why_i_run?: string | null
        }
        Update: {
          avatar_url?: string | null
          bio?: string | null
          city?: string | null
          current_tier?: Database["public"]["Enums"]["loyalty_tier"] | null
          favorite_distance?: string | null
          full_name?: string | null
          id?: string | null
          last_activity_at?: string | null
          last_streak_weeks?: number | null
          max_streak_weeks?: number | null
          profile_photo_urls?: string[] | null
          running_level?: Database["public"]["Enums"]["running_level"] | null
          running_since?: string | null
          why_i_run?: string | null
        }
        Relationships: []
      }
      training_with_counts: {
        Row: {
          cover_image_url: string | null
          created_at: string | null
          description: string | null
          distance_km: number | null
          id: string | null
          location_maps_url: string | null
          location_name: string | null
          max_capacity: number | null
          pacer_id: string | null
          recommended_level: string | null
          registration_count: number | null
          scheduled_at: string | null
          sponsor_id: string | null
          status: Database["public"]["Enums"]["training_status"] | null
          title: string | null
        }
        Relationships: [
          {
            foreignKeyName: "trainings_pacer_id_fkey"
            columns: ["pacer_id"]
            isOneToOne: false
            referencedRelation: "pacers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trainings_sponsor_id_fkey"
            columns: ["sponsor_id"]
            isOneToOne: false
            referencedRelation: "sponsors"
            referencedColumns: ["id"]
          },
        ]
      }
      trainings_web: {
        Row: {
          cupos_totales: number | null
          estado: string | null
          fecha_hora: string | null
          id: string | null
          latitud: number | null
          longitud: number | null
          pacer_nombre: string | null
          preguntas_extra: Json | null
          titulo_entrenamiento: string | null
          ubicacion: string | null
          ubicacion_texto: string | null
        }
        Insert: {
          cupos_totales?: number | null
          estado?: never
          fecha_hora?: string | null
          id?: string | null
          latitud?: number | null
          longitud?: number | null
          pacer_nombre?: string | null
          preguntas_extra?: never
          titulo_entrenamiento?: string | null
          ubicacion?: string | null
          ubicacion_texto?: string | null
        }
        Update: {
          cupos_totales?: number | null
          estado?: never
          fecha_hora?: string | null
          id?: string | null
          latitud?: number | null
          longitud?: number | null
          pacer_nombre?: string | null
          preguntas_extra?: never
          titulo_entrenamiento?: string | null
          ubicacion?: string | null
          ubicacion_texto?: string | null
        }
        Relationships: []
      }
      user_tier_progress: {
        Row: {
          current_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          current_tier_color: string | null
          current_tier_emoji: string | null
          current_tier_name: string | null
          next_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          next_tier_min_points: number | null
          next_tier_name: string | null
          points_to_next_tier: number | null
          total_points: number | null
          user_id: string | null
        }
        Relationships: []
      }
      vw_social_feed: {
        Row: {
          author_id: string | null
          avatar: string | null
          created_at: string | null
          description: string | null
          event_data: Json | null
          event_id: string | null
          event_type: Database["public"]["Enums"]["post_type"] | null
          likes_count: number | null
          media_urls: string[] | null
          my_reaction: string | null
          ref_id: string | null
          runner_city: string | null
          runner_name: string | null
          runner_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          visibility: Database["public"]["Enums"]["post_visibility"] | null
        }
        Relationships: []
      }
      vw_wsr_conversations: {
        Row: {
          channel_id: string | null
          counterpart_avatar: string | null
          counterpart_id: string | null
          counterpart_name: string | null
          counterpart_tier: string | null
          has_unread: boolean | null
          is_archived: boolean | null
          is_muted: boolean | null
          last_message_at: string | null
          last_msg_body: string | null
          last_msg_created_at: string | null
          last_msg_deleted_at: string | null
          last_msg_id: string | null
          last_msg_kind: string | null
          last_msg_sender_id: string | null
          last_read_at: string | null
          my_role: Database["public"]["Enums"]["participant_role"] | null
          name: string | null
          type: Database["public"]["Enums"]["channel_type"] | null
        }
        Relationships: []
      }
      wsr_blocks: {
        Row: {
          blocked_id: string | null
          blocker_id: string | null
          created_at: string | null
        }
        Insert: {
          blocked_id?: string | null
          blocker_id?: string | null
          created_at?: string | null
        }
        Update: {
          blocked_id?: string | null
          blocker_id?: string | null
          created_at?: string | null
        }
        Relationships: []
      }
      wsr_conversations: {
        Row: {
          avatar_url: string | null
          created_at: string | null
          created_by: string | null
          description: string | null
          id: string | null
          is_archived: boolean | null
          last_message_at: string | null
          name: string | null
          type: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string | null
          is_archived?: boolean | null
          last_message_at?: string | null
          name?: string | null
          type?: never
        }
        Update: {
          avatar_url?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          id?: string | null
          is_archived?: boolean | null
          last_message_at?: string | null
          name?: string | null
          type?: never
        }
        Relationships: []
      }
      wsr_messages: {
        Row: {
          body: string | null
          conversation_id: string | null
          created_at: string | null
          deleted_at: string | null
          edited_at: string | null
          id: string | null
          kind: string | null
          sender_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "messages_channel_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "channels"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_channel_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "vw_wsr_conversations"
            referencedColumns: ["channel_id"]
          },
          {
            foreignKeyName: "messages_channel_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "wsr_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      wsr_reports: {
        Row: {
          content_id: string | null
          content_type: string | null
          created_at: string | null
          details: string | null
          id: string | null
          reason: string | null
          reported_id: string | null
          reporter_id: string | null
          status: string | null
        }
        Insert: {
          content_id?: string | null
          content_type?: never
          created_at?: string | null
          details?: string | null
          id?: string | null
          reason?: never
          reported_id?: string | null
          reporter_id?: string | null
          status?: never
        }
        Update: {
          content_id?: string | null
          content_type?: never
          created_at?: string | null
          details?: string | null
          id?: string | null
          reason?: never
          reported_id?: string | null
          reporter_id?: string | null
          status?: never
        }
        Relationships: []
      }
    }
    Functions: {
      add_training_leader: {
        Args: { p_role: string; p_training_id: string; p_user_id: string }
        Returns: undefined
      }
      assign_training_coach: {
        Args: { p_coach_id: string; p_training_id: string }
        Returns: undefined
      }
      assign_training_pacer: {
        Args: { p_pacer_user_id: string; p_training_id: string }
        Returns: undefined
      }
      assign_winner_code: {
        Args: { p_distancia?: string; p_event_id: string; p_winner_id: string }
        Returns: string
      }
      award_points: {
        Args: {
          p_description: string
          p_event_type: string
          p_points: number
          p_reference: string
          p_user_id: string
        }
        Returns: undefined
      }
      award_points_by_rule: {
        Args: {
          p_custom_desc?: string
          p_event_type: string
          p_reference?: string
          p_user_id: string
        }
        Returns: boolean
      }
      award_streak_bonus_if_needed: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      block_user: { Args: { p_target: string }; Returns: undefined }
      calculate_tier: {
        Args: { p_points: number }
        Returns: Database["public"]["Enums"]["loyalty_tier"]
      }
      can_earn_points: {
        Args: { p_event_type: string; p_reference?: string; p_user_id: string }
        Returns: boolean
      }
      channel_has_block: {
        Args: { p_channel_id: string; p_me?: string }
        Returns: boolean
      }
      check_ai_rate_limit: {
        Args: { p_limit?: number; p_user_id: string; p_window_minutes?: number }
        Returns: boolean
      }
      create_direct_channel: { Args: { p_other_user: string }; Returns: string }
      create_group_channel: {
        Args: { p_description?: string; p_members?: string[]; p_name: string }
        Returns: string
      }
      evaluate_achievements: { Args: { p_user_id: string }; Returns: undefined }
      find_app_user_by_email: { Args: { p_email: string }; Returns: string }
      finish_activity: {
        Args: {
          p_distance_m: number
          p_duration_s: number
          p_ended_at: string
          p_feeling?: Database["public"]["Enums"]["activity_feeling"]
          p_is_shared?: boolean
          p_notes?: string
          p_polyline?: string
          p_started_at: string
          p_title?: string
          p_visibility?: string
        }
        Returns: string
      }
      fn_adapt_plan: {
        Args: { p_adaptations: Json; p_plan_id: string }
        Returns: string
      }
      fn_admin_delete_anamnesis: { Args: { p_id: string }; Returns: undefined }
      fn_admin_resolve_health_alert: {
        Args: { p_alert_id: string; p_status?: string }
        Returns: {
          alert_type: string
          check_in_id: string | null
          created_at: string
          id: string
          reason: string
          resolved_at: string | null
          resolved_by: string | null
          runner_id: string
          session_id: string | null
          severity: string
          status: string
        }
        SetofOptions: {
          from: "*"
          to: "health_alerts"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      fn_admin_update_training_session: {
        Args: {
          p_coach_notes: string
          p_cooldown_desc?: string
          p_description: string
          p_distance_km: number
          p_duration_min: number
          p_intensity: string
          p_main_desc?: string
          p_pace_target: string
          p_rpe_target: number
          p_session_id: string
          p_session_type: string
          p_title: string
          p_warmup_desc?: string
        }
        Returns: {
          coach_notes: string | null
          completed_at: string | null
          cooldown_desc: string | null
          created_at: string
          day_of_week: number
          description: string | null
          distance_km: number | null
          duration_min: number | null
          id: string
          intensity: string
          main_desc: string | null
          pace_target: string | null
          rpe_target: number | null
          session_type: string
          status: string
          title: string | null
          updated_at: string
          warmup_desc: string | null
          week_id: string
        }
        SetofOptions: {
          from: "*"
          to: "training_sessions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      fn_admin_upsert_anamnesis: {
        Args: { p_id: string; p_payload: Json }
        Returns: string
      }
      fn_anamnesis_token_valido: {
        Args: { p_token_id: string }
        Returns: boolean
      }
      fn_coach_owns_plan: { Args: { p_plan_id: string }; Returns: boolean }
      fn_coach_owns_runner: { Args: { p_runner_id: string }; Returns: boolean }
      fn_coach_owns_week: { Args: { p_week_id: string }; Returns: boolean }
      fn_complete_session_from_app: {
        Args: {
          p_actual_duration?: number
          p_actual_rpe?: number
          p_notes?: string
          p_pain_score?: number
          p_runner_id?: string
          p_session_id: string
        }
        Returns: {
          actual_distance_km: number | null
          actual_duration_min: number | null
          actual_rpe: number | null
          completed_at: string
          created_at: string
          id: string
          notes: string | null
          pain_location: string | null
          pain_score: number
          plan_id: string | null
          runner_id: string
          source: string
          training_session_id: string
        }
        SetofOptions: {
          from: "*"
          to: "session_results"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      fn_forget_runner: {
        Args: { p_reason?: string; p_runner_id: string }
        Returns: Json
      }
      fn_get_community_score: { Args: { p_runner_id: string }; Returns: number }
      fn_is_admin_or_super: { Args: never; Returns: boolean }
      fn_is_coach: { Args: never; Returns: boolean }
      fn_runner_id_for_user: { Args: never; Returns: string }
      fn_runner_owns_plan: { Args: { p_plan_id: string }; Returns: boolean }
      fn_runner_owns_week: { Args: { p_week_id: string }; Returns: boolean }
      fn_submit_check_in: {
        Args: {
          p_comments?: string
          p_email: string
          p_energy: number
          p_life_changes?: boolean
          p_life_changes_detail?: string
          p_motivation: number
          p_pain: number
          p_pain_location?: string
          p_sessions_completed: number
          p_sessions_planned: number
          p_sleep_quality: number
        }
        Returns: Json
      }
      fn_submit_check_in_token: {
        Args: {
          p_comments?: string
          p_energy: number
          p_life_changes?: boolean
          p_life_changes_detail?: string
          p_motivation: number
          p_pain: number
          p_pain_location?: string
          p_sessions_completed: number
          p_sessions_planned: number
          p_sleep_quality: number
          p_token: string
        }
        Returns: Json
      }
      fn_validate_anamnesis_token: { Args: { p_token: string }; Returns: Json }
      fn_validate_checkin_token: { Args: { p_token: string }; Returns: Json }
      get_active_checkins: {
        Args: { p_training_id: string }
        Returns: {
          avatar_url: string
          checked_in_at: string
          full_name: string
          user_id: string
        }[]
      }
      get_coach_options: {
        Args: never
        Returns: {
          full_name: string
          label: string
          user_id: string
        }[]
      }
      get_comeback_info: { Args: never; Returns: Json }
      get_completed_sessions: { Args: { p_user_id: string }; Returns: number }
      get_conversation_messages:
        | {
            Args: { p_channel_id: string; p_cursor?: string; p_limit?: number }
            Returns: {
              body: string
              channel_id: string
              created_at: string
              deleted_at: string
              edited_at: string
              id: string
              kind: string
              sender_avatar: string
              sender_id: string
              sender_name: string
              sender_tier: string
            }[]
          }
        | {
            Args: {
              p_before?: string
              p_conversation_id: string
              p_limit?: number
            }
            Returns: {
              body: string
              conversation_id: string
              created_at: string
              deleted_at: string
              edited_at: string
              id: string
              kind: string
              sender_id: string
            }[]
          }
      get_current_streak: { Args: { p_user_id: string }; Returns: number }
      get_followup_recipients: {
        Args: { p_secret: string; p_training_id: string }
        Returns: {
          asistio: boolean
          email: string
          nombre: string
        }[]
      }
      get_moderation_queue: {
        Args: { p_limit?: number; p_status?: string }
        Returns: {
          content_id: string
          content_type: string
          created_at: string
          details: string
          reason: string
          report_id: string
          reported_id: string
          reported_name: string
          reporter_id: string
          reporter_name: string
          resolution_note: string
          reviewed_at: string
          reviewed_by: string
          status: string
        }[]
      }
      get_my_active_plan: {
        Args: { p_runner_id?: string }
        Returns: {
          actual_rpe: number
          coach_message: string
          completed_at: string
          cooldown_desc: string
          day_of_week: number
          delivered_at: string
          distance_km: number
          duration_min: number
          intensity: string
          main_desc: string
          pace_target: string
          pain_score: number
          plan_goal: string
          plan_id: string
          plan_title: string
          result_id: string
          rpe_target: number
          session_desc: string
          session_id: string
          session_status: string
          session_title: string
          session_type: string
          version_tag: string
          warmup_desc: string
          week_focus: string
          week_id: string
          week_number: number
          week_type: string
          weekly_km_target: number
        }[]
      }
      get_my_assigned_trainings: {
        Args: never
        Returns: {
          coach_id: string | null
          cover_image_url: string | null
          created_at: string
          descripcion: string | null
          description: string | null
          distance_km: number | null
          id: string
          imagen_url: string | null
          latitude: number | null
          location_detail: string | null
          location_maps_url: string | null
          location_name: string
          longitude: number | null
          max_capacity: number
          nivel_objetivo: string | null
          pacer_id: string | null
          pacer_nombre: string | null
          pacer_user_id: string | null
          preguntas_extra: Json | null
          puntos_asistencia: number
          recommended_level: string
          scheduled_at: string
          sponsor_event_id: string | null
          sponsor_id: string | null
          status: Database["public"]["Enums"]["training_status"]
          tipo_entrenamiento: string | null
          title: string
          training_kind: string
          training_type: Database["public"]["Enums"]["training_type"]
        }[]
        SetofOptions: {
          from: "*"
          to: "trainings"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_my_blocked_profiles: {
        Args: never
        Returns: {
          avatar_url: string
          blocked_at: string
          blocked_id: string
          city: string
          current_tier: string
          full_name: string
          reason: string
        }[]
      }
      get_my_followers: {
        Args: { p_user_id: string }
        Returns: {
          avatar_url: string
          city: string
          current_tier: string
          followed_at: string
          full_name: string
          id: string
          running_level: string
        }[]
      }
      get_my_following: {
        Args: { p_user_id: string }
        Returns: {
          avatar_url: string
          city: string
          current_tier: string
          followed_at: string
          follows_back: boolean
          full_name: string
          id: string
          running_level: string
        }[]
      }
      get_my_week_checkin: {
        Args: never
        Returns: {
          created_at: string
          energy: number
          id: string
          motivation: number
          note: string | null
          pain: number
          sleep: number
          trainings_completed: number
          user_id: string
          week_start: string
        }
        SetofOptions: {
          from: "*"
          to: "checkins"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_pacer_options: {
        Args: { p_training_id: string }
        Returns: {
          full_name: string
          label: string
          user_id: string
        }[]
      }
      get_recent_checkins: {
        Args: { p_limit?: number }
        Returns: {
          created_at: string
          energy: number
          id: string
          mood: string
          note: string | null
          user_id: string
        }[]
        SetofOptions: {
          from: "*"
          to: "emotional_checkins"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_reports_for_moderation: {
        Args: { p_status?: Database["public"]["Enums"]["report_status"] }
        Returns: {
          content_id: string
          content_type: Database["public"]["Enums"]["report_target"]
          created_at: string
          details: string
          id: string
          reason: Database["public"]["Enums"]["report_reason"]
          reported_name: string
          reported_user_id: string
          reporter_id: string
          reporter_name: string
          resolution_note: string
          reviewed_at: string
          status: Database["public"]["Enums"]["report_status"]
        }[]
      }
      get_social_feed: {
        Args: { p_cursor?: string; p_limit?: number }
        Returns: {
          author_id: string | null
          avatar: string | null
          created_at: string | null
          description: string | null
          event_data: Json | null
          event_id: string | null
          event_type: Database["public"]["Enums"]["post_type"] | null
          likes_count: number | null
          media_urls: string[] | null
          my_reaction: string | null
          ref_id: string | null
          runner_city: string | null
          runner_name: string | null
          runner_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          visibility: Database["public"]["Enums"]["post_visibility"] | null
        }[]
        SetofOptions: {
          from: "*"
          to: "vw_social_feed"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_social_feed_following: {
        Args: { p_limit?: number; p_offset?: string; p_user_id?: string }
        Returns: {
          author_id: string | null
          avatar: string | null
          created_at: string | null
          description: string | null
          event_data: Json | null
          event_id: string | null
          event_type: Database["public"]["Enums"]["post_type"] | null
          likes_count: number | null
          media_urls: string[] | null
          my_reaction: string | null
          ref_id: string | null
          runner_city: string | null
          runner_name: string | null
          runner_tier: Database["public"]["Enums"]["loyalty_tier"] | null
          visibility: Database["public"]["Enums"]["post_visibility"] | null
        }[]
        SetofOptions: {
          from: "*"
          to: "vw_social_feed"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_training_leaders: {
        Args: { p_training_id: string }
        Returns: {
          full_name: string
          label: string
          role: string
          user_id: string
        }[]
      }
      get_training_participants: {
        Args: { p_training_id: string }
        Returns: {
          avatar_url: string
          city: string
          current_tier: string
          full_name: string
          running_level: string
          user_id: string
        }[]
      }
      get_user_group_ids: { Args: { p_user_id?: string }; Returns: string[] }
      has_role: {
        Args: {
          p_role: Database["public"]["Enums"]["app_role"]
          p_user_id: string
        }
        Returns: boolean
      }
      inscribir_en_entrenamiento: {
        Args: {
          p_anexo_a_aceptado_en?: string
          p_anexo_a_requerido?: boolean
          p_anexo_a_vigencia?: string
          p_condicion_medica: string
          p_condiciones_declaradas?: string[]
          p_contacto_emergencia: string
          p_email: string
          p_nombre: string
          p_respuestas_extra?: Json
          p_telefono?: string
          p_tiene_condicion_medica?: boolean
          p_training_id: string
        }
        Returns: undefined
      }
      is_blocked_between: {
        Args: { p_me?: string; p_other: string }
        Returns: boolean
      }
      is_channel_admin: {
        Args: { p_channel_id: string; p_user_id?: string }
        Returns: boolean
      }
      is_channel_participant: {
        Args: { p_channel_id: string; p_user_id?: string }
        Returns: boolean
      }
      join_community_space: { Args: { p_channel_id: string }; Returns: string }
      leave_channel: { Args: { p_channel_id: string }; Returns: undefined }
      promote_from_waitlist: {
        Args: { p_training_id: string }
        Returns: undefined
      }
      qualify_referral_if_needed: {
        Args: { p_referred_id: string }
        Returns: undefined
      }
      record_user_activity: { Args: { p_user_id: string }; Returns: undefined }
      redeem_reward: {
        Args: { p_reward_id: string; p_user_id: string }
        Returns: string
      }
      remove_training_leader: {
        Args: { p_training_id: string; p_user_id: string }
        Returns: undefined
      }
      report_user: {
        Args: {
          p_content_id?: string
          p_content_type?: string
          p_details?: string
          p_reason?: string
          p_reported_user: string
        }
        Returns: string
      }
      resolve_sos_alert: { Args: { p_alert_id: string }; Returns: undefined }
      send_message:
        | { Args: { p_body: string; p_channel_id: string }; Returns: string }
        | {
            Args: {
              p_body: string
              p_conversation_id: string
              p_kind?: Database["public"]["Enums"]["message_kind"]
            }
            Returns: string
          }
      send_sos_alert: {
        Args: { p_lat?: number; p_lng?: number; p_training_id: string }
        Returns: string
      }
      start_gps_broadcast: { Args: { p_training_id: string }; Returns: string }
      stop_gps_broadcast: {
        Args: { p_training_id: string }
        Returns: undefined
      }
      submit_emotional_checkin: {
        Args: { p_energy: number; p_mood: string; p_note?: string }
        Returns: {
          created_at: string
          energy: number
          id: string
          mood: string
          note: string | null
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "emotional_checkins"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      submit_weekly_checkin: {
        Args: {
          p_energy: number
          p_motivation: number
          p_note?: string
          p_pain: number
          p_sleep: number
          p_trainings_completed: number
        }
        Returns: {
          created_at: string
          energy: number
          id: string
          motivation: number
          note: string | null
          pain: number
          sleep: number
          trainings_completed: number
          user_id: string
          week_start: string
        }
        SetofOptions: {
          from: "*"
          to: "checkins"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      toggle_reaction: {
        Args: {
          p_post_id: string
          p_reaction?: Database["public"]["Enums"]["reaction_kind"]
        }
        Returns: string
      }
      unblock_user: { Args: { p_target: string }; Returns: undefined }
      upsert_user_onboarding: {
        Args: {
          p_barriers: string[]
          p_cycle_opt_in: boolean
          p_energy_baseline: number
          p_motivations: string[]
          p_running_relationship: string
          p_support_style: string
        }
        Returns: {
          barriers: string[]
          completed_at: string | null
          cycle_opt_in: boolean
          energy_baseline: number | null
          motivations: string[]
          running_relationship: string | null
          support_style: string | null
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "user_onboarding"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      activity_feeling: "genial" | "bien" | "normal" | "cansada" | "dificil"
      app_role:
        | "runner"
        | "coach"
        | "moderator"
        | "admin"
        | "super_admin"
        | "pacer"
      channel_type: "direct" | "group" | "community"
      loyalty_tier: "starter" | "runner" | "elite" | "champion"
      message_kind: "text" | "image" | "system"
      notification_kind:
        | "new_message"
        | "new_training"
        | "support_reaction"
        | "anti_abandonment"
        | "general"
      participant_role: "owner" | "admin" | "member"
      personal_training_status: "assigned" | "completed" | "skipped"
      post_type:
        | "free_run"
        | "training_completed"
        | "achievement"
        | "milestone"
        | "streak"
        | "text"
        | "photo"
        | "new_runner"
        | "personal_training_completed"
      post_visibility: "public" | "followers" | "private"
      reaction_kind: "apoyo" | "fuerza" | "celebro" | "orgullo"
      redemption_status:
        | "pending"
        | "approved"
        | "delivered"
        | "rejected"
        | "cancelled"
      referral_status: "pending" | "registered" | "qualified"
      registration_status: "confirmed" | "cancelled" | "waitlist"
      report_reason:
        | "acoso"
        | "spam"
        | "contenido_inapropiado"
        | "discurso_odio"
        | "suplantacion"
        | "otro"
      report_status: "pendiente" | "en_revision" | "resuelto" | "descartado"
      report_target: "post" | "message" | "profile"
      running_level: "principiante" | "intermedio" | "avanzada"
      training_feeling: "genial" | "bien" | "normal" | "cansada" | "dificil"
      training_status: "draft" | "published" | "cancelled" | "completed"
      training_type:
        | "rodaje"
        | "intervalos"
        | "fondo"
        | "fuerza"
        | "movilidad"
        | "recuperacion"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      activity_feeling: ["genial", "bien", "normal", "cansada", "dificil"],
      app_role: [
        "runner",
        "coach",
        "moderator",
        "admin",
        "super_admin",
        "pacer",
      ],
      channel_type: ["direct", "group", "community"],
      loyalty_tier: ["starter", "runner", "elite", "champion"],
      message_kind: ["text", "image", "system"],
      notification_kind: [
        "new_message",
        "new_training",
        "support_reaction",
        "anti_abandonment",
        "general",
      ],
      participant_role: ["owner", "admin", "member"],
      personal_training_status: ["assigned", "completed", "skipped"],
      post_type: [
        "free_run",
        "training_completed",
        "achievement",
        "milestone",
        "streak",
        "text",
        "photo",
        "new_runner",
        "personal_training_completed",
      ],
      post_visibility: ["public", "followers", "private"],
      reaction_kind: ["apoyo", "fuerza", "celebro", "orgullo"],
      redemption_status: [
        "pending",
        "approved",
        "delivered",
        "rejected",
        "cancelled",
      ],
      referral_status: ["pending", "registered", "qualified"],
      registration_status: ["confirmed", "cancelled", "waitlist"],
      report_reason: [
        "acoso",
        "spam",
        "contenido_inapropiado",
        "discurso_odio",
        "suplantacion",
        "otro",
      ],
      report_status: ["pendiente", "en_revision", "resuelto", "descartado"],
      report_target: ["post", "message", "profile"],
      running_level: ["principiante", "intermedio", "avanzada"],
      training_feeling: ["genial", "bien", "normal", "cansada", "dificil"],
      training_status: ["draft", "published", "cancelled", "completed"],
      training_type: [
        "rodaje",
        "intervalos",
        "fondo",
        "fuerza",
        "movilidad",
        "recuperacion",
      ],
    },
  },
} as const
