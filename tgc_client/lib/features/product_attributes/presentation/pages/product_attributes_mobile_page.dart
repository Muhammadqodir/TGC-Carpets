import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/product_attributes_repository.dart';
import '../bloc/product_attributes_bloc.dart';
import '../bloc/product_attributes_event.dart';
import '../bloc/product_attributes_state.dart';
import '../widgets/attribute_form_dialogs.dart';
import '../widgets/attribute_list_panel.dart';
import '../widgets/delete_with_replace_dialog.dart';

class ProductAttributesMobilePage extends StatefulWidget {
  const ProductAttributesMobilePage({super.key});

  @override
  State<ProductAttributesMobilePage> createState() =>
      _ProductAttributesMobilePageState();
}

class _ProductAttributesMobilePageState
    extends State<ProductAttributesMobilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['Ranglar', 'Turlar', 'Sifatlar', 'O\'lchamlar'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductAttributesBloc, ProductAttributesState>(
      listenWhen: (prev, curr) =>
          curr is ProductAttributesLoaded &&
          prev is ProductAttributesLoaded &&
          curr.actionStatus != prev.actionStatus,
      listener: (context, state) =>
          handleAttributeActionStatus(context, state),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mahsulot atributlari'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedReload,
                strokeWidth: 2.5,
              ),
              onPressed: () => context
                  .read<ProductAttributesBloc>()
                  .add(const ProductAttributesRefreshRequested()),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: BlocBuilder<ProductAttributesBloc, ProductAttributesState>(
          builder: (context, state) {
            if (state is ProductAttributesLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ProductAttributesError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context
                          .read<ProductAttributesBloc>()
                          .add(const ProductAttributesRefreshRequested()),
                      child: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              );
            }
            if (state is ProductAttributesLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  // ── Colors ────────────────────────────────────────────────
                  AttributeListPanel<dynamic>(
                    title: 'Ranglar',
                    items: state.colors,
                    itemLabel: (c) => c.name as String,
                    itemSubtitle: (_) => null,
                    emptyMessage: 'Ranglar topilmadi.',
                    onAdd: () => SimpleAttributeFormDialog.show(
                      context,
                      title: 'Rang qo\'shish',
                      fieldLabel: 'Rang nomi',
                      fieldHint: 'masalan: Qizil',
                      onSubmit: (ctx, value) {
                        ctx.read<ProductAttributesBloc>().add(ColorCreateRequested(value));
                      },
                    ),
                    onEdit: (c) => SimpleAttributeFormDialog.show(
                      context,
                      title: 'Rangni tahrirlash',
                      fieldLabel: 'Rang nomi',
                      fieldHint: 'masalan: Qizil',
                      initialValue: c.name as String,
                      onSubmit: (ctx, value) {
                        ctx.read<ProductAttributesBloc>().add(
                              ColorUpdateRequested(id: c.id as int, name: value),
                            );
                      },
                    ),
                    onDelete: (c) async {
                      final result = await DeleteWithReplaceDialog.show<dynamic>(
                        context: context,
                        itemName: c.name as String,
                        attributeTypeName: 'rang',
                        usageFuture: sl<ProductAttributesRepository>()
                            .checkColorUsage(id: c.id as int)
                            .then((e) => e.fold((_) => 0, (v) => v)),
                        replacements: state.colors.where((x) => x.id != c.id).toList(),
                        replacementLabel: (x) => x.name as String,
                        replacementId: (x) => x.id as int,
                      );
                      if (result.confirmed && context.mounted) {
                        context.read<ProductAttributesBloc>().add(
                          ColorDeleteRequested(c.id as int, replaceWithId: result.replaceWithId),
                        );
                      }
                    },
                  ),

                  // ── Product Types ──────────────────────────────────────────
                  AttributeListPanel<dynamic>(
                    title: 'Mahsulot turlari',
                    items: state.productTypes,
                    itemLabel: (t) => t.type as String,
                    itemSubtitle: (_) => null,
                    emptyMessage: 'Mahsulot turlari topilmadi.',
                    onAdd: () => SimpleAttributeFormDialog.show(
                      context,
                      title: 'Tur qo\'shish',
                      fieldLabel: 'Tur nomi',
                      fieldHint: 'masalan: Gilam',
                      onSubmit: (ctx, value) {
                        ctx.read<ProductAttributesBloc>().add(ProductTypeCreateRequested(value));
                      },
                    ),
                    onEdit: (t) => SimpleAttributeFormDialog.show(
                      context,
                      title: 'Turni tahrirlash',
                      fieldLabel: 'Tur nomi',
                      fieldHint: 'masalan: Gilam',
                      initialValue: t.type as String,
                      onSubmit: (ctx, value) {
                        ctx.read<ProductAttributesBloc>().add(
                              ProductTypeUpdateRequested(id: t.id as int, type: value),
                            );
                      },
                    ),
                    onDelete: (t) async {
                      final result = await DeleteWithReplaceDialog.show<dynamic>(
                        context: context,
                        itemName: t.type as String,
                        attributeTypeName: 'tur',
                        usageFuture: sl<ProductAttributesRepository>()
                            .checkProductTypeUsage(id: t.id as int)
                            .then((e) => e.fold((_) => 0, (v) => v)),
                        replacements: state.productTypes.where((x) => x.id != t.id).toList(),
                        replacementLabel: (x) => x.type as String,
                        replacementId: (x) => x.id as int,
                      );
                      if (result.confirmed && context.mounted) {
                        context.read<ProductAttributesBloc>().add(
                          ProductTypeDeleteRequested(t.id as int, replaceWithId: result.replaceWithId),
                        );
                      }
                    },
                  ),

                  // ── Product Qualities ──────────────────────────────────────
                  AttributeListPanel<dynamic>(
                    title: 'Sifatlar',
                    items: state.productQualities,
                    itemLabel: (q) => q.qualityName as String,
                    itemSubtitle: (q) {
                      final d = q.density;
                      return d != null ? 'Zichlik: $d' : null;
                    },
                    emptyMessage: 'Sifatlar topilmadi.',
                    onAdd: () => QualityFormDialog.show(
                      context,
                      onSubmit: (ctx, name, density) {
                        ctx.read<ProductAttributesBloc>().add(
                              ProductQualityCreateRequested(qualityName: name, density: density),
                            );
                      },
                    ),
                    onEdit: (q) => QualityFormDialog.show(
                      context,
                      initialName: q.qualityName as String,
                      initialDensity: q.density as int?,
                      onSubmit: (ctx, name, density) {
                        ctx.read<ProductAttributesBloc>().add(
                              ProductQualityUpdateRequested(
                                id: q.id as int,
                                qualityName: name,
                                density: density,
                              ),
                            );
                      },
                    ),
                    onDelete: (q) async {
                      final result = await DeleteWithReplaceDialog.show<dynamic>(
                        context: context,
                        itemName: q.qualityName as String,
                        attributeTypeName: 'sifat',
                        usageFuture: sl<ProductAttributesRepository>()
                            .checkProductQualityUsage(id: q.id as int)
                            .then((e) => e.fold((_) => 0, (v) => v)),
                        replacements: state.productQualities.where((x) => x.id != q.id).toList(),
                        replacementLabel: (x) => x.qualityName as String,
                        replacementId: (x) => x.id as int,
                      );
                      if (result.confirmed && context.mounted) {
                        context.read<ProductAttributesBloc>().add(
                          ProductQualityDeleteRequested(q.id as int, replaceWithId: result.replaceWithId),
                        );
                      }
                    },
                  ),

                  // ── Product Sizes ──────────────────────────────────────────
                  AttributeListPanel<dynamic>(
                    title: 'O\'lchamlar',
                    items: state.productSizes,
                    itemLabel: (s) => s.dimensions as String,
                    itemSubtitle: (s) {
                      final typeId = s.productTypeId as int;
                      final type = state.productTypes
                          .where((t) => t.id == typeId)
                          .map((t) => t.type)
                          .firstOrNull;
                      return type != null ? 'Tur: $type' : null;
                    },
                    emptyMessage: 'O\'lchamlar topilmadi.',
                    onAdd: () => SizeFormDialog.show(
                      context,
                      productTypes: state.productTypes,
                      onSubmit: (ctx, length, width, typeId) {
                        ctx.read<ProductAttributesBloc>().add(
                              ProductSizeCreateRequested(
                                length: length,
                                width: width,
                                productTypeId: typeId,
                              ),
                            );
                      },
                    ),
                    onEdit: (s) => SizeFormDialog.show(
                      context,
                      initialLength: s.length as int,
                      initialWidth: s.width as int,
                      initialProductTypeId: s.productTypeId as int,
                      productTypes: state.productTypes,
                      onSubmit: (ctx, length, width, typeId) {
                        ctx.read<ProductAttributesBloc>().add(
                              ProductSizeUpdateRequested(
                                id: s.id as int,
                                length: length,
                                width: width,
                                productTypeId: typeId,
                              ),
                            );
                      },
                    ),
                    onDelete: (s) async {
                      final result = await DeleteWithReplaceDialog.show<dynamic>(
                        context: context,
                        itemName: s.dimensions as String,
                        attributeTypeName: 'o\'lcham',
                        usageFuture: sl<ProductAttributesRepository>()
                            .checkProductSizeUsage(id: s.id as int)
                            .then((e) => e.fold((_) => 0, (v) => v)),
                        replacements: state.productSizes.where((x) => x.id != s.id).toList(),
                        replacementLabel: (x) => x.dimensions as String,
                        replacementId: (x) => x.id as int,
                      );
                      if (result.confirmed && context.mounted) {
                        context.read<ProductAttributesBloc>().add(
                          ProductSizeDeleteRequested(s.id as int, replaceWithId: result.replaceWithId),
                        );
                      }
                    },
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
