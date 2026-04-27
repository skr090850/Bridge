import 'package:bridge/Server/server_url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../projects/model/project_model.dart';
import '../projects/model/folder_model.dart';

class NewTicketScreen extends StatefulWidget {
  final Project project;
  const NewTicketScreen({super.key, required this.project});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  late Future<List<Folder>> _foldersFuture;
  Folder? _selectedFolder;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _foldersFuture = _fetchFolders(widget.project.projectId);
  }

  Future<List<Folder>> _fetchFolders(int projectId) async {
    final String apiUrl =
        '${baseUrl}Template/GetprojFolders?tid=1&projid=$projectId';
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final dynamic body = json.decode(response.body);
      final List<dynamic> data = body is String ? json.decode(body) : body;
      return data.map((json) => Folder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load folders');
    }
  }
  
  void _submitTicket(){
    if(_formKey.currentState!.validate()){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket submitted successfully! (DEMO)'), backgroundColor: Colors.green,)
      );
      Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Ticket'),
        actions: [
          IconButton(onPressed: (){}, icon: const Icon(Icons.camera_alt_outlined)),
          IconButton(onPressed: (){}, icon: const Icon(Icons.image_outlined)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected Project', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${widget.project.title}\nCustomer ID: ${widget.project.projectId}'),
              const SizedBox(height: 16),
              
              const Text('Select Folder', style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<List<Folder>>(
                future: _foldersFuture,
                builder: (context, snapshot){
                   if (snapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                   }
                   if(snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty){
                     return const Text('Could not load folders.');
                   }
                   final folders = snapshot.data!;
                   return DropdownButtonFormField<Folder>(
                     value: _selectedFolder,
                     hint: const Text('Select a folder'),
                     isExpanded: true,
                     items: folders.map((folder) {
                       return DropdownMenuItem(value: folder, child: Text(folder.name));
                     }).toList(),
                     onChanged: (value){
                       setState(() {
                         _selectedFolder = value;
                       });
                     },
                     validator: (value) => value == null ? 'Please select a folder' : null,
                   );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                 validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitTicket,
                  child: const Text('SUBMIT'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
