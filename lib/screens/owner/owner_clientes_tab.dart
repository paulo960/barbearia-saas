// 1. Os Imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;

class ClientesScreen extends StatefulWidget {
  final String barbeariaId;
  const ClientesScreen({super.key, required this.barbeariaId});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _buscaCtrl = TextEditingController();
  String _termoBusca = '';

  
