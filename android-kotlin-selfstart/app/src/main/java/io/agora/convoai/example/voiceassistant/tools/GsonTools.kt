package io.agora.convoai.example.voiceassistant.tools

import com.google.gson.*
import com.google.gson.reflect.TypeToken
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import org.json.JSONObject
import java.io.IOException
import java.lang.reflect.ParameterizedType
import java.lang.reflect.Type

object GsonTools {
    private val gson =
        _root_ide_package_.com.google.gson.GsonBuilder()
            .setDateFormat("yyyy-MM-dd HH:mm:ss").setObjectToNumberStrategy(_root_ide_package_.com.google.gson.ToNumberPolicy.LONG_OR_DOUBLE)
            .registerTypeAdapter(_root_ide_package_.com.google.gson.reflect.TypeToken.get(JSONObject::class.java).type, object : com.google.gson.TypeAdapter<JSONObject>() {
                @Throws(IOException::class)
                override fun write(jsonWriter: com.google.gson.stream.JsonWriter, value: JSONObject) {
                    jsonWriter.jsonValue(value.toString())
                }

                @Throws(IOException::class)
                override fun read(jsonReader: com.google.gson.stream.JsonReader): JSONObject? {
                    return null
                }
            })
            .enableComplexMapKeySerialization()
            .create()

    @JvmStatic
    fun beanToString(obj: Any?): String? {
        if(obj is String){
            return obj
        }
        return try {
            gson.toJson(obj)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    @JvmStatic
    fun <T> toBean(jsonString: String?, clazz: Class<T>): T? {
        return try {
            gson.fromJson(jsonString, clazz)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    @JvmStatic
    fun <T> toBean(jsonString: String?, type: Type): T? {
        return try {
            gson.fromJson(jsonString, type)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    @JvmStatic
    fun <T> toBean(element: com.google.gson.JsonElement?, cls: Class<T>?): T? {
        return try {
            gson.fromJson(element, cls)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    @JvmStatic
    fun beanToMap(obj: Any): Map<String, Any> {
        return try {
            gson.fromJson(gson.toJson(obj), object : com.google.gson.reflect.TypeToken<Map<String, Any>>() {}.type)
        } catch (e: Exception) {
            emptyMap()
        }
    }

    @JvmStatic
    fun <T> toMap(jsonString: String?, clazz: Class<T>): Map<String, T>? {
        return try {
            gson.fromJson(jsonString, ParameterizedTypeMapImpl(clazz))
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    @JvmStatic
    fun <T> toList(gsonString: String?, clazz:Class<T>): List<T>? {
        return try {
            gson.fromJson(gsonString, ParameterizedTypeListImpl(clazz))
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    @JvmStatic
    fun getBoolean(jsonObject: JSONObject?, valueKey: String?, defaultValue: Boolean): Boolean {
        if (jsonObject == null || valueKey == null) return defaultValue
        var value = defaultValue
        if (jsonObject.has(valueKey)) try {
            value = jsonObject.getBoolean(valueKey)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return value
    }

    @JvmStatic
    fun getInt(jsonObject: JSONObject?, valueKey: String?): Int {
        if (jsonObject == null || valueKey == null) return 0
        var value = 0
        if (jsonObject.has(valueKey)) try {
            value = jsonObject.getInt(valueKey)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return value
    }

    @JvmStatic
    fun getLong(jsonObject: JSONObject?, valueKey: String?): Long {
        if (jsonObject == null || valueKey == null) return 0L
        var value = 0L
        if (jsonObject.has(valueKey)) try {
            value = jsonObject.getLong(valueKey)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return value
    }

    @JvmStatic
    fun getString(jsonObject: JSONObject?, valueKey: String?): String {
        if (jsonObject == null || valueKey == null) return ""
        var value = ""
        if (jsonObject.has(valueKey)) try {
            value = jsonObject.getString(valueKey)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return value
    }


}

internal class ParameterizedTypeListImpl(var clazz: Class<*>) : ParameterizedType {
    override fun getActualTypeArguments(): Array<Type> {
        return arrayOf(clazz)
    }

    override fun getRawType(): Type {
        return List::class.java
    }

    override fun getOwnerType(): Type? {
        return null
    }
}

internal class ParameterizedTypeMapImpl(var clazz: Class<*>) : ParameterizedType {
    override fun getActualTypeArguments(): Array<Type> {
        return arrayOf(clazz)
    }

    override fun getRawType(): Type {
        return Map::class.java
    }

    override fun getOwnerType(): Type? {
        return null
    }
}